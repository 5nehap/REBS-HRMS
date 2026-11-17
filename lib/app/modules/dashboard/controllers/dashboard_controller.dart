import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/office_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/employee_model.dart';
import '../../../data/models/leave_balance_model.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/leave_repository.dart';

class DashboardController extends GetxController {
  final EmployeeRepository employeeRepository;
  final AttendanceRepository attendanceRepository;
  final LeaveRepository leaveRepository;
  final ConnectivityService? connectivityService;

  DashboardController({
    required this.employeeRepository,
    required this.attendanceRepository,
    required this.leaveRepository,
    this.connectivityService,
  });

  static const String currentEmployeeId = 'EMP-001';

  final RxBool isLoading = false.obs;
  final RxBool isOffline = false.obs;
  final RxString errorMessage = ''.obs;

  final Rx<EmployeeModel?> currentEmployee = Rx<EmployeeModel?>(null);
  final Rx<LeaveBalanceModel?> leaveBalance = Rx<LeaveBalanceModel?>(null);

  final Rx<AttendanceModel?> todayAttendanceRecord = Rx<AttendanceModel?>(null);
  final RxString todayAttendanceStatus = 'Not Checked In'.obs;
  final RxString todayCheckInTime = '--'.obs;
  final RxString todayCheckOutTime = '--'.obs;
  final RxString workingDuration = '00h 00m'.obs;

  final RxList<AttendanceModel> latestAttendance = <AttendanceModel>[].obs;
  final RxSet<String> pendingEventDates = <String>{}.obs;
  final RxSet<String> rejectedEventDates = <String>{}.obs;

  Timer? _durationTimer;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void onInit() {
    super.onInit();
    debugPrint(
      '[DashboardController] Initialized for employee $currentEmployeeId',
    );

    // Initial offline state from service if available
    if (connectivityService != null) {
      isOffline.value = !connectivityService!.isOnline.value;
      _connectivitySubscription = connectivityService!.isOnline.listen((
        online,
      ) {
        isOffline.value = !online;
        if (online) {
          debugPrint(
            '[DashboardController] Online connection restored. Refreshing dashboard...',
          );
          loadDashboardData();
        }
      });
    }

    // Start periodic timer to recalculate active working duration
    _startDurationTimer();

    loadDashboardData();
  }

  @override
  void onClose() {
    _durationTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.onClose();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (todayAttendanceStatus.value == 'Checked In') {
        final inTimeIso = todayAttendanceRecord.value?.checkInTimestamp;
        final outTimeIso = todayAttendanceRecord.value?.checkOutTimestamp;
        workingDuration.value = calculateWorkingDuration(
          inTimeIso,
          outTimeIso,
        );
      }
    });
  }

  /// Calculates elapsed or completed working duration between check-in and check-out.
  /// Guarantees non-negative duration, formatting as `XXh YYm`.
  static String calculateWorkingDuration(
    String? checkInIso,
    String? checkOutIso, {
    DateTime? currentTime,
  }) {
    if (checkInIso == null || checkInIso.trim().isEmpty) {
      return '00h 00m';
    }

    final checkIn = DateHelper.parseDate(checkInIso);
    if (checkIn == null) {
      return '00h 00m';
    }

    final end = (checkOutIso != null && checkOutIso.trim().isNotEmpty)
        ? DateHelper.parseDate(checkOutIso)
        : (currentTime ?? DateTime.now());

    if (end == null || end.isBefore(checkIn)) {
      return '00h 00m';
    }

    final difference = end.difference(checkIn);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
  }

  /// Resolves the sync chip status for a given working date
  String getSyncStatusForDate(String workingDate) {
    if (pendingEventDates.contains(workingDate)) {
      return AppConstants.syncPending;
    }
    if (rejectedEventDates.contains(workingDate)) {
      return AppConstants.syncRejected;
    }
    return AppConstants.syncSynced;
  }

  /// Refreshes all dashboard sections: profile, today's attendance, leave balance, and recent history
  Future<void> loadDashboardData() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      if (connectivityService != null) {
        isOffline.value = !connectivityService!.isOnline.value;
      }

      // 1. Load employee profile (SQLite cache first, API if online)
      await _loadEmployeeProfile();

      // 2. Load today's attendance and working duration
      await refreshTodayAttendanceStatus();

      // 3. Load leave balance (SQLite cache first, API if online)
      await _loadLeaveBalance();

      // 4. Load latest 5 attendance records
      await _loadLatestAttendanceRecords();
    } catch (e, stack) {
      debugPrint('[DashboardController] Error loading dashboard: $e\n$stack');
      errorMessage.value = 'Failed to load dashboard data. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Loads employee profile with SQLite persistence and remote sync
  Future<void> _loadEmployeeProfile() async {
    try {
      EmployeeModel? emp = await employeeRepository.getEmployeeProfile(
        currentEmployeeId,
      );

      final online = connectivityService?.isOnline.value ?? true;
      if (online) {
        try {
          final remoteEmp = await employeeRepository.fetchCurrentEmployee();
          emp = remoteEmp;
        } catch (e) {
          debugPrint(
            '[DashboardController] Remote employee fetch failed (using cache): $e',
          );
        }
      }

      emp ??=EmployeeModel(
        id: currentEmployeeId,
        name: 'Alex Johnson',
        department: 'Engineering',
        officeLatitude: OfficeConfig.officeLatitude,
        officeLongitude: OfficeConfig.officeLongitude,
        companyTimezone: 'Asia/Kolkata',
      );

      currentEmployee.value = emp;
    } catch (e) {
      debugPrint('[DashboardController] Employee profile loading error: $e');
    }
  }

  /// Loads leave balances with SQLite persistence and remote sync
  Future<void> _loadLeaveBalance() async {
    try {
      LeaveBalanceModel? balance = await leaveRepository.getCachedLeaveBalance(
        currentEmployeeId,
      );

      final online = connectivityService?.isOnline.value ?? true;
      if (online) {
        try {
          final remoteBalance = await leaveRepository.fetchLeaveBalance(
            employeeId: currentEmployeeId,
          );
          balance = remoteBalance;
        } catch (e) {
          debugPrint(
            '[DashboardController] Remote leave balance fetch failed (using cache): $e',
          );
        }
      }

      balance ??=  LeaveBalanceModel(
        casualLeave: 8,
        sickLeave: 5,
        totalAvailableLeave: 13,
      );

      leaveBalance.value = balance;
    } catch (e) {
      debugPrint('[DashboardController] Leave balance loading error: $e');
    }
  }

  /// Directly recalculates today's attendance status, timestamps, and working duration from SQLite
  Future<void> refreshTodayAttendanceStatus() async {
    try {
      final todayStr = DateHelper.formatDate(DateTime.now());

      // Read local daily record
      final record = await attendanceRepository.getTodayAttendance(
        currentEmployeeId,
        todayStr,
      );
      todayAttendanceRecord.value = record;

      // Read pending and all events to capture queued updates
      final pendingList = await attendanceRepository.getPendingEvents(
        currentEmployeeId,
      );
      pendingEventDates.assignAll(pendingList.map((e) => e.workingDate));

      final allEvents = await attendanceRepository.getAllEvents(
        currentEmployeeId,
      );
      rejectedEventDates.assignAll(
        allEvents
            .where((e) => e.syncStatus == AppConstants.syncRejected)
            .map((e) => e.workingDate),
      );

      // Derive today status ('Checked Out', 'Checked In', or 'Not Checked In')
      final status = await attendanceRepository.deriveTodayAttendanceStatus(
        currentEmployeeId,
        todayStr,
      );
      todayAttendanceStatus.value = status;

      // Determine in/out timestamps (checking record first, then fallback to pending events)
      String? inTimeIso = record?.checkInTimestamp;
      String? outTimeIso = record?.checkOutTimestamp;

      final todayEvents = pendingList
          .where((e) => e.workingDate == todayStr)
          .toList();

      if (inTimeIso == null) {
        final inEvent = todayEvents.firstWhereOrNull(
          (e) => e.eventType == AppConstants.eventCheckIn,
        );
        inTimeIso = inEvent?.timestamp;
      }

      if (outTimeIso == null) {
        final outEvent = todayEvents.firstWhereOrNull(
          (e) => e.eventType == AppConstants.eventCheckOut,
        );
        outTimeIso = outEvent?.timestamp;
      }

      todayCheckInTime.value = _formatIsoTime(inTimeIso);
      todayCheckOutTime.value = _formatIsoTime(outTimeIso);

      workingDuration.value = calculateWorkingDuration(
        inTimeIso,
        outTimeIso,
      );

      debugPrint(
        '[DashboardController] Today status: $status, In: ${todayCheckInTime.value}, Out: ${todayCheckOutTime.value}, Duration: ${workingDuration.value}',
      );
    } catch (e) {
      debugPrint('[DashboardController] Failed to derive today status: $e');
    }
  }

  /// Loads latest 5 attendance records sorted newest first, avoiding dummy filler items
  Future<void> _loadLatestAttendanceRecords() async {
    try {
      final todayStr = DateHelper.formatDate(DateTime.now());
      final currentMonthStr = todayStr.substring(0, 7);

      // If online, attempt to fetch remote history and safely merge with SQLite
      final online = connectivityService?.isOnline.value ?? true;
      if (online) {
        try {
          final remoteRecords = await attendanceRepository
              .fetchAttendanceHistory(month: currentMonthStr);
          await attendanceRepository.syncAndMergeServerRecords(
            currentEmployeeId,
            remoteRecords,
          );
        } catch (e) {
          debugPrint(
            '[DashboardController] Remote history fetch failed (using local SQLite cache): $e',
          );
        }
      }

      // Query latest records from SQLite (ordered by working_date DESC)
      final records = await attendanceRepository.getLatestAttendanceRecords(
        currentEmployeeId,
        limit: 5,
      );

      // Ensure today's local summary is included if present
      final mergedMap = <String, AttendanceModel>{};
      for (final r in records) {
        mergedMap[r.workingDate] = r;
      }

      if (todayAttendanceRecord.value != null) {
        mergedMap[todayAttendanceRecord.value!.workingDate] =
            todayAttendanceRecord.value!;
      }

      // Sort descending (newest first) and take at most 5 items
      final sorted = mergedMap.values.toList()
        ..sort((a, b) => b.workingDate.compareTo(a.workingDate));

      final limited = sorted.length > 5 ? sorted.sublist(0, 5) : sorted;
      latestAttendance.assignAll(limited);

      debugPrint(
        '[DashboardController] Loaded ${latestAttendance.length} latest attendance records.',
      );
    } catch (e) {
      debugPrint(
        '[DashboardController] Error loading latest attendance records: $e',
      );
    }
  }

  String _formatIsoTime(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '--';
    final parsed = DateHelper.parseDate(iso);
    if (parsed == null) return '--';
    return DateHelper.formatTime(parsed);
  }
}
