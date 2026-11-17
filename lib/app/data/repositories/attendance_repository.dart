import '../models/attendance_model.dart';
import '../models/attendance_event_model.dart';
import '../providers/api_provider.dart';
import '../providers/local_database.dart';

class AttendanceRepository {
  final ApiProvider apiProvider;
  final LocalDatabase localDatabase;

  AttendanceRepository({
    required this.apiProvider,
    required this.localDatabase,
  });

  /// Fetches monthly attendance history from API (`/attendance?month=YYYY-MM`).
  Future<List<AttendanceModel>> fetchAttendanceHistory({String? month}) async {
    final queryParams = <String, dynamic>{};
    if (month != null && month.isNotEmpty) {
      queryParams['month'] = month;
    }

    final response = await apiProvider.get(
      '/attendance',
      queryParameters: queryParams,
    );

    final data = response.data;
    List<dynamic> list;
    if (data is Map<String, dynamic> && data['data'] is List) {
      list = data['data'] as List<dynamic>;
    } else if (data is List) {
      list = data;
    } else {
      list = [];
    }

    final remoteRecords = list
        .map((e) => AttendanceModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return remoteRecords;
  }

  /// Sends an attendance event to the API (`POST /attendance/events`).
  /// Sends the stable event `id` directly to preserve event idempotency.
  /// Does not automatically retry with a new event ID.
  Future<Map<String, dynamic>> postAttendanceEvent(
    AttendanceEventModel event,
  ) async {
    final response = await apiProvider.post(
      '/attendance/events',
      data: {
        'eventId': event.id,
        'employeeId': event.employeeId,
        'eventType': event.eventType,
        'timestamp': event.timestamp,
        'latitude': event.latitude,
        'longitude': event.longitude,
      },
    );

    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  // ==========================================
  // LOCAL SQLITE STORAGE METHODS
  // ==========================================

  /// Saves a batch of attendance records into SQLite.
  Future<void> saveAttendanceRecords(List<AttendanceModel> records) async {
    await localDatabase.upsertAttendanceBatch(records);
  }

  /// Saves a single attendance record into SQLite.
  Future<void> saveSingleAttendanceRecord(AttendanceModel record) async {
    await localDatabase.upsertAttendance(record);
  }

  /// Gets today's attendance record for an employee.
  Future<AttendanceModel?> getTodayAttendance(
    String employeeId,
    String workingDate,
  ) async {
    return await localDatabase.getTodayAttendance(employeeId, workingDate);
  }

  /// Gets monthly attendance history from local database.
  Future<List<AttendanceModel>> getMonthlyAttendanceHistory(
    String employeeId,
    String yearMonth,
  ) async {
    return await localDatabase.getMonthlyAttendance(employeeId, yearMonth);
  }

  /// Gets latest five attendance records for an employee from local database.
  Future<List<AttendanceModel>> getLatestAttendanceRecords(
    String employeeId, {
    int limit = 5,
  }) async {
    return await localDatabase.getLatestAttendanceRecords(
      employeeId,
      limit: limit,
    );
  }

  // ==========================================
  // PERSISTENT ATTENDANCE EVENT QUEUE METHODS
  // ==========================================

  /// Inserts a pending attendance event into persistent queue with transaction.
  /// Preserves event ordering and UUID idempotency.
  Future<bool> insertPendingAttendanceEvent(AttendanceEventModel event) async {
    return await localDatabase.insertPendingAttendanceEvent(event);
  }

  /// Retrieves pending events in chronological order (FIFO) for synchronization.
  Future<List<AttendanceEventModel>> getPendingEvents(String employeeId) async {
    return await localDatabase.getPendingAttendanceEvents(employeeId);
  }

  /// Retrieves all recorded events (Pending, Synced, Rejected) for an employee.
  Future<List<AttendanceEventModel>> getAllEvents(String employeeId) async {
    return await localDatabase.getAllAttendanceEvents(employeeId);
  }

  /// Marks an event as SYNCED in the persistent queue.
  Future<void> markEventSynced(String eventId) async {
    await localDatabase.markEventSynced(eventId);
  }

  /// Marks an event as REJECTED with server reason in the persistent queue.
  Future<void> markEventRejected(String eventId, String reason) async {
    await localDatabase.markEventRejected(eventId, reason);
  }

  /// Increments retry count and updates timestamp following network attempt.
  Future<void> updateRetryMetadata(String eventId) async {
    await localDatabase.incrementEventRetry(eventId);
  }

  /// Derives today's attendance status from SQLite local source of truth
  /// incorporating any locally pending and rejected attendance events.
  Future<String> deriveTodayAttendanceStatus(
    String employeeId,
    String workingDate,
  ) async {
    // 1. Check local daily attendance record
    final record = await getTodayAttendance(employeeId, workingDate);

    // 2. Check pending/stored events for this working date
    final pendingEvents = await getPendingEvents(employeeId);
    final todayEvents = pendingEvents
        .where((e) => e.workingDate == workingDate)
        .toList();

    final hasCheckOut =
        record?.checkOutTimestamp != null ||
        todayEvents.any((e) => e.eventType == 'CHECK_OUT');

    if (hasCheckOut) {
      return 'Checked Out';
    }

    final hasCheckIn =
        record?.checkInTimestamp != null ||
        todayEvents.any((e) => e.eventType == 'CHECK_IN');

    if (hasCheckIn) {
      return 'Checked In';
    }

    return 'Not Checked In';
  }

  /// Safely merges server attendance records with locally saved records without
  /// overwriting local working dates that contain pending unsynced events.
  /// Preserves local SQLite as source of truth and caches server history.
  Future<void> syncAndMergeServerRecords(
    String employeeId,
    List<AttendanceModel> serverRecords,
  ) async {
    if (serverRecords.isEmpty) return;

    // Get all pending events to identify dates that have local uncommitted changes
    final pendingList = await getPendingEvents(employeeId);
    final pendingDates = pendingList.map((e) => e.workingDate).toSet();

    final safeToSave = <AttendanceModel>[];
    for (final serverRecord in serverRecords) {
      // If today or a date has pending local events, do NOT overwrite local state with stale server state
      if (!pendingDates.contains(serverRecord.workingDate)) {
        safeToSave.add(serverRecord);
      }
    }

    if (safeToSave.isNotEmpty) {
      await saveAttendanceRecords(safeToSave);
    }
  }
}
