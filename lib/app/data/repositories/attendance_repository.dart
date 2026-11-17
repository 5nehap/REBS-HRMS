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

  /// Fetches monthly attendance history from API (`/attendance?month=YYYY-MM`)
  /// and updates local database cache.
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

    final records = list
        .map((e) => AttendanceModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Cache fetched records to local storage
    if (records.isNotEmpty) {
      await saveAttendanceRecords(records);
    }

    return records;
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
}
