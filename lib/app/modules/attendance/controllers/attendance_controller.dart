import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/attendance_event_model.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../logics/attendance_logic.dart';
import '../../../logics/sync_logic.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

class AttendanceController extends GetxController
    with WidgetsBindingObserver {
  final AttendanceRepository attendanceRepository;
  final AttendanceLogic attendanceLogic;
  final SyncLogic syncLogic;

  AttendanceController({
    required this.attendanceRepository,
    required this.attendanceLogic,
    required this.syncLogic,
  });

  static const String currentEmployeeId = 'EMP-001';

  final RxBool isLoading = false.obs;
  final RxBool isActionLoading = false.obs;
  final RxString actionTypeLoading = ''.obs; // 'CHECK_IN' or 'CHECK_OUT'
  final RxBool isSyncing = false.obs;
  final RxList<AttendanceModel> history = <AttendanceModel>[].obs;
  final Rx<AttendanceModel?> todayAttendance = Rx<AttendanceModel?>(null);
  final RxList<AttendanceEventModel> pendingEvents =
      <AttendanceEventModel>[].obs;
  final RxList<AttendanceEventModel> allEvents = <AttendanceEventModel>[].obs;

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _autoSyncPeriodicTimer;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    debugPrint(
      '[AttendanceController] Initialized for employee $currentEmployeeId',
    );
    loadAttendanceData();

    // 1. Listen for connectivity returning to attempt automatic sync
    _connectivitySubscription = syncLogic.connectivityService.isOnline.listen((
      online,
    ) {
      if (online && pendingEvents.isNotEmpty && !isSyncing.value) {
        debugPrint(
          '[AttendanceController] Connectivity restored. Attempting auto-sync...',
        );
        syncNow(isAutomatic: true);
      }
    });

    // 2. Start bounded background retry timer while pending events exist
    _startPeriodicSyncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[AttendanceController] App resumed. Checking auto-sync...');
      if (pendingEvents.isNotEmpty &&
          !isSyncing.value &&
          syncLogic.connectivityService.isOnline.value) {
        syncNow(isAutomatic: true);
      }
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _autoSyncPeriodicTimer?.cancel();
    super.onClose();
  }

  void _startPeriodicSyncTimer() {
    _autoSyncPeriodicTimer?.cancel();
    _autoSyncPeriodicTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (pendingEvents.isNotEmpty &&
          !isSyncing.value &&
          !isActionLoading.value &&
          syncLogic.connectivityService.isOnline.value) {
        debugPrint(
          '[AttendanceController] Periodic auto-sync check triggered for ${pendingEvents.length} pending event(s)...',
        );
        syncNow(isAutomatic: true);
      }
    });
  }

  /// Determines the sync status of an attendance item:
  /// - Returns 'PENDING' if any event for that date is in pending status.
  /// - Returns 'REJECTED' if any event for that date was rejected.
  /// - Returns 'SYNCED' if all events are synced or it came from server.
  String getSyncStatusForDate(String workingDate) {
    if (pendingEvents.any((e) => e.workingDate == workingDate)) {
      return AppConstants.syncPending;
    }
    if (allEvents.any(
      (e) =>
          e.workingDate == workingDate &&
          e.syncStatus == AppConstants.syncRejected,
    )) {
      return AppConstants.syncRejected;
    }
    return AppConstants.syncSynced;
  }

  /// Loads today's attendance, monthly history (remote + SQLite cache), and pending sync events
  Future<void> loadAttendanceData() async {
    isLoading.value = true;
    try {
      final todayStr = DateHelper.formatDate(DateTime.now());
      final currentMonthStr = todayStr.substring(0, 7); // YYYY-MM

      // 1. Fetch pending and all events from SQLite queue
      final pendingList = await attendanceRepository.getPendingEvents(
        currentEmployeeId,
      );
      pendingEvents.assignAll(pendingList);

      final allRecordedEvents = await attendanceRepository.getAllEvents(
        currentEmployeeId,
      );
      allEvents.assignAll(allRecordedEvents);

      // 2. Fetch today's record from local SQLite storage
      final todayRecord = await attendanceRepository.getTodayAttendance(
        currentEmployeeId,
        todayStr,
      );
      todayAttendance.value = todayRecord;

      // 3. Attempt to fetch monthly attendance history from Mock API if online
      if (syncLogic.connectivityService.isOnline.value) {
        try {
          debugPrint(
            '[AttendanceController] Fetching remote attendance history for month $currentMonthStr...',
          );
          final remoteRecords = await attendanceRepository
              .fetchAttendanceHistory(month: currentMonthStr);
          debugPrint(
            '[AttendanceController] Fetched ${remoteRecords.length} records from remote server.',
          );

          // Safely merge with SQLite without overwriting dates with pending local events
          await attendanceRepository.syncAndMergeServerRecords(
            currentEmployeeId,
            remoteRecords,
          );
        } catch (e) {
          debugPrint(
            '[AttendanceController] Remote attendance fetch failed (offline/error): $e. Using local SQLite cache.',
          );
        }
      }

      // 4. Retrieve complete monthly attendance records from SQLite
      final localHistory = await attendanceRepository
          .getMonthlyAttendanceHistory(currentEmployeeId, currentMonthStr);

      // 5. Ensure today's local attendance record is included if not yet in list
      final mergedMap = <String, AttendanceModel>{};
      for (final item in localHistory) {
        mergedMap[item.workingDate] = item;
      }

      if (todayRecord != null) {
        mergedMap[todayRecord.workingDate] = todayRecord;
      }

      // Sort newest first (e.g. 2026-11-17, 2026-11-15, 2026-11-14)
      final sortedList = mergedMap.values.toList()
        ..sort((a, b) => b.workingDate.compareTo(a.workingDate));

      history.assignAll(sortedList);
      debugPrint(
        '[AttendanceController] Data loaded. Today: ${todayAttendance.value?.workingDate}, Total History: ${history.length}, Pending: ${pendingEvents.length}',
      );
    } catch (e, stack) {
      debugPrint(
        '[AttendanceController] Error loading attendance data: $e\n$stack',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAttendanceHistory() async {
    await loadAttendanceData();
  }

  /// Check In Action
  Future<void> checkIn() async {
    debugPrint('[AttendanceController] checkIn() button pressed');
    await _recordAttendanceEvent(AppConstants.eventCheckIn);
  }

  /// Check Out Action
  Future<void> checkOut() async {
    debugPrint('[AttendanceController] checkOut() button pressed');
    await _recordAttendanceEvent(AppConstants.eventCheckOut);
  }

  /// Synchronize Pending Attendance Events Now
  Future<void> syncNow({bool isAutomatic = false}) async {
    if (isSyncing.value) {
      debugPrint(
        '[AttendanceController] Sync already running. Ignoring trigger.',
      );
      return;
    }

    if (pendingEvents.isEmpty) {
      if (!isAutomatic) {
        _showInfoSnackbar(
          title: 'Already Synchronized',
          message: 'No pending attendance events to synchronize.',
        );
      }
      return;
    }

    if (!syncLogic.connectivityService.isOnline.value) {
      if (!isAutomatic) {
        _showInfoSnackbar(
          title: 'Offline Mode',
          message:
              'Attendance saved locally. It will sync when the server is available.',
        );
      }
      return;
    }

    isSyncing.value = true;
    debugPrint(
      '[AttendanceController] Starting manual/auto attendance sync...',
    );

    try {
      final summary = await syncLogic.synchronizePendingAttendanceEvents(
        currentEmployeeId,
      );

      // Reload local state from SQLite and API
      await loadAttendanceData();

      // Refresh Dashboard
      if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().refreshTodayAttendanceStatus();
      }

      if (!isAutomatic) {
        if (summary.allSynced) {
          _showSuccessSnackbar(
            title: 'Synchronization Complete',
            message:
                'Successfully synchronized ${summary.syncedCount} attendance event(s) with the server.',
          );
        } else if (summary.syncedCount > 0 && summary.pendingCount > 0) {
          _showInfoSnackbar(
            title: 'Partial Sync',
            message:
                'Synced ${summary.syncedCount} event(s). ${summary.pendingCount} event(s) remain pending.',
          );
        } else if (summary.rejectedCount > 0) {
          _showErrorSnackbar(
            title: 'Sync Rejected',
            message:
                summary.firstError ??
                'One or more events were rejected by the server.',
          );
        } else if (summary.firstError != null) {
          _showInfoSnackbar(
            title: 'Attendance Saved Locally',
            message:
                'Attendance saved locally. It will sync when the server is available.',
          );
        }
      }
    } catch (e, stack) {
      debugPrint('[AttendanceController] Error in syncNow: $e\n$stack');
      if (!isAutomatic) {
        final friendlyMsg = NetworkErrorHandler.getAttendanceErrorMessage(e);
        _showInfoSnackbar(
          title: 'Attendance Saved Locally',
          message: friendlyMsg,
        );
      }
    } finally {
      isSyncing.value = false;
      debugPrint('[AttendanceController] Sync finished. isSyncing reset.');
    }
  }

  /// Core Attendance Event Pipeline
  Future<void> _recordAttendanceEvent(String eventType) async {
    if (isActionLoading.value) {
      debugPrint(
        '[AttendanceController] Action already in progress, ignoring duplicate tap',
      );
      return;
    }

    final todayStr = DateHelper.formatDate(DateTime.now());

    // 1. Duplicate check validation before requesting GPS
    if (eventType == AppConstants.eventCheckIn) {
      if (todayAttendance.value?.checkInTimestamp != null) {
        debugPrint(
          '[AttendanceController] Check-in rejected: already checked in today',
        );
        _showErrorSnackbar(
          title: 'Already Checked In',
          message: 'You have already checked in for today ($todayStr).',
        );
        return;
      }
    } else if (eventType == AppConstants.eventCheckOut) {
      if (todayAttendance.value?.checkInTimestamp == null) {
        debugPrint(
          '[AttendanceController] Check-out rejected: no check-in recorded for today',
        );
        _showErrorSnackbar(
          title: 'Check-In Required',
          message: 'You must check in before checking out.',
        );
        return;
      }
      if (todayAttendance.value?.checkOutTimestamp != null) {
        debugPrint(
          '[AttendanceController] Check-out rejected: already checked out today',
        );
        _showErrorSnackbar(
          title: 'Already Checked Out',
          message: 'You have already checked out for today ($todayStr).',
        );
        return;
      }
    }

    isActionLoading.value = true;
    actionTypeLoading.value = eventType;

    try {
      debugPrint(
        '[AttendanceController] Validating GPS location for $eventType...',
      );

      // 2. Obtain current GPS position
      final position = await attendanceLogic.getCurrentPosition();

      // 3. Validate 200m office perimeter
      final validation = attendanceLogic.validateAttendanceLocation(position);

      if (position == null || !validation.isValid) {
        debugPrint(
          '[AttendanceController] GPS Geofence validation failed: ${validation.errorMessage}',
        );
        _showErrorSnackbar(
          title: 'Location Restriction',
          message:
              validation.errorMessage ??
              'You must be within 200 metres of the office to mark attendance.',
        );
        return;
      }

      debugPrint(
        '[AttendanceController] Location validated (${validation.distanceMeters?.toStringAsFixed(1)}m from office). Recording event...',
      );

      // 4. Construct unique attendance event model with stable UUID
      final now = DateTime.now();
      final eventId = const Uuid().v4();
      final isoTimestamp = now.toIso8601String();

      final event = AttendanceEventModel(
        id: eventId,
        employeeId: currentEmployeeId,
        eventType: eventType,
        timestamp: isoTimestamp,
        workingDate: todayStr,
        latitude: position.latitude,
        longitude: position.longitude,
        syncStatus: AppConstants.syncPending,
        createdAt: isoTimestamp,
      );

      debugPrint(
        '[AttendanceController] Inserting pending event $eventId into SQLite queue...',
      );

      // 5. Persist attendance event in SQLite offline queue
      final inserted = await attendanceRepository.insertPendingAttendanceEvent(
        event,
      );

      if (!inserted) {
        debugPrint(
          '[AttendanceController] Duplicate event ID detected: $eventId',
        );
        _showErrorSnackbar(
          title: 'Duplicate Event',
          message: 'An event with this ID has already been recorded.',
        );
        return;
      }

      // 6. Update today's local attendance record in SQLite & memory
      AttendanceModel currentToday =
          todayAttendance.value ??
          AttendanceModel(
            id: 'ATT-$todayStr',
            employeeId: currentEmployeeId,
            workingDate: todayStr,
            attendanceStatus: 'Present',
          );

      if (eventType == AppConstants.eventCheckIn) {
        currentToday = currentToday.copyWith(
          checkInTimestamp: isoTimestamp,
          attendanceStatus: 'Present',
        );
      } else {
        currentToday = currentToday.copyWith(checkOutTimestamp: isoTimestamp);
      }

      await attendanceRepository.saveSingleAttendanceRecord(currentToday);

      // 7. Refresh reactive states
      todayAttendance.value = currentToday;
      pendingEvents.add(event);
      allEvents.add(event);

      // Update DashboardController if registered
      if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().refreshTodayAttendanceStatus();
      }

      // Update or prepend in history list
      final existingIndex = history.indexWhere(
        (h) => h.workingDate == todayStr,
      );
      if (existingIndex >= 0) {
        history[existingIndex] = currentToday;
      } else {
        history.insert(0, currentToday);
      }

      debugPrint(
        '[AttendanceController] Successfully marked $eventType locally (Pending Sync)',
      );

      // 8. Reset action loading flag BEFORE triggering synchronization
      isActionLoading.value = false;
      actionTypeLoading.value = '';

      // 9. Immediately attempt background synchronization if network is available
      if (syncLogic.connectivityService.isOnline.value) {
        debugPrint(
          '[AttendanceController] Network available. Immediately attempting synchronization for $eventType...',
        );

        final syncSummary = await syncLogic.synchronizePendingAttendanceEvents(
          currentEmployeeId,
        );

        if (syncSummary.allSynced) {
          debugPrint(
            '[AttendanceController] Immediate auto-sync succeeded for event $eventId.',
          );
          await loadAttendanceData();
          if (Get.isRegistered<DashboardController>()) {
            Get.find<DashboardController>().refreshTodayAttendanceStatus();
          }

          _showSuccessSnackbar(
            title:
                '${eventType == AppConstants.eventCheckIn ? "Check-In" : "Check-Out"} Successful',
            message: 'Attendance recorded and synchronized with server.',
          );
          return;
        } else {
          debugPrint(
            '[AttendanceController] Immediate sync postponed. Event remains Pending Sync in SQLite.',
          );
        }
      }

      // If offline or backend was temporarily unreachable, display friendly pending notification
      _showInfoSnackbar(
        title:
            '${eventType == AppConstants.eventCheckIn ? "Check-In" : "Check-Out"} Recorded',
        message:
            'Attendance saved locally. It will sync when the server is available.',
      );
    } catch (e, stack) {
      debugPrint(
        '[AttendanceController] Exception during $eventType: $e\n$stack',
      );
      final friendlyMsg = NetworkErrorHandler.getAttendanceErrorMessage(e);
      _showErrorSnackbar(title: 'Attendance Error', message: friendlyMsg);
    } finally {
      // 10. Always guarantee action loading state reset
      isActionLoading.value = false;
      actionTypeLoading.value = '';
      debugPrint('[AttendanceController] Action loading flag reset complete');
    }
  }

  void _showErrorSnackbar({required String title, required String message}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: Colors.white,
      icon: const Icon(Icons.error_outline, color: Colors.white),
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
    );
  }

  void _showSuccessSnackbar({required String title, required String message}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: Colors.white,
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
    );
  }

  void _showInfoSnackbar({required String title, required String message}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.info,
      colorText: Colors.white,
      icon: const Icon(Icons.info_outline, color: Colors.white),
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
    );
  }
}
