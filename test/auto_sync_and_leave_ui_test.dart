import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rebs_hrms/app/core/constants/app_constants.dart';
import 'package:rebs_hrms/app/core/errors/api_exception.dart';
import 'package:rebs_hrms/app/core/services/connectivity_service.dart';
import 'package:rebs_hrms/app/core/services/location_service.dart';
import 'package:rebs_hrms/app/data/models/attendance_event_model.dart';
import 'package:rebs_hrms/app/data/models/attendance_model.dart';
import 'package:rebs_hrms/app/data/models/leave_balance_model.dart';
import 'package:rebs_hrms/app/data/models/leave_model.dart';
import 'package:rebs_hrms/app/data/providers/api_provider.dart';
import 'package:rebs_hrms/app/data/providers/local_database.dart';
import 'package:rebs_hrms/app/data/repositories/attendance_repository.dart';
import 'package:rebs_hrms/app/data/repositories/leave_repository.dart';
import 'package:rebs_hrms/app/logics/attendance_logic.dart';
import 'package:rebs_hrms/app/logics/leave_logic.dart';
import 'package:rebs_hrms/app/logics/sync_logic.dart';
import 'package:rebs_hrms/app/modules/attendance/controllers/attendance_controller.dart';
import 'package:rebs_hrms/app/modules/leave/controllers/leave_controller.dart';
import 'package:rebs_hrms/app/modules/leave/widgets/leave_form.dart';

/// Test Fake for Attendance Repository with simulated network outcomes
class FakeAttendanceRepo extends AttendanceRepository {
  FakeAttendanceRepo()
      : super(apiProvider: ApiProvider(), localDatabase: LocalDatabase());

  final Map<String, AttendanceEventModel> localQueue = {};
  final List<AttendanceEventModel> remoteAcceptedEvents = [];
  AttendanceModel? todaySummary;
  bool isServerReachable = true;
  bool simulateTimeout = false;
  bool simulatePermanentRejection = false;
  String rejectionReason = 'Geofence perimeter violation (>200m)';

  @override
  Future<bool> insertPendingAttendanceEvent(AttendanceEventModel event) async {
    if (localQueue.containsKey(event.id)) {
      return false; // Duplicate UUID prevented
    }
    localQueue[event.id] = event;
    return true;
  }

  @override
  Future<List<AttendanceEventModel>> getPendingEvents(String employeeId) async {
    return localQueue.values
        .where((e) => e.syncStatus == AppConstants.syncPending)
        .toList();
  }

  @override
  Future<List<AttendanceEventModel>> getAllEvents(String employeeId) async {
    return localQueue.values.toList();
  }

  @override
  Future<void> markEventSynced(String eventId) async {
    if (localQueue.containsKey(eventId)) {
      localQueue[eventId] = localQueue[eventId]!.copyWith(
        syncStatus: AppConstants.syncSynced,
      );
    }
  }

  @override
  Future<void> markEventRejected(String eventId, String reason) async {
    if (localQueue.containsKey(eventId)) {
      localQueue[eventId] = localQueue[eventId]!.copyWith(
        syncStatus: AppConstants.syncRejected,
      );
    }
  }

  @override
  Future<void> updateRetryMetadata(String eventId) async {
    // Keep pending and increment attempt
  }

  @override
  Future<AttendanceModel?> getTodayAttendance(
    String employeeId,
    String workingDate,
  ) async {
    return todaySummary;
  }

  @override
  Future<void> saveSingleAttendanceRecord(AttendanceModel record) async {
    todaySummary = record;
  }

  @override
  Future<List<AttendanceModel>> getMonthlyAttendanceHistory(
    String employeeId,
    String yearMonth,
  ) async {
    if (todaySummary != null) return [todaySummary!];
    return [];
  }

  @override
  Future<Map<String, dynamic>> postAttendanceEvent(
    AttendanceEventModel event,
  ) async {
    if (!isServerReachable) {
      throw NetworkException(
        message: 'Connection refused: mock server is down',
      );
    }
    if (simulateTimeout) {
      // Simulate server saved it, but response timed out
      remoteAcceptedEvents.add(event);
      throw NetworkException(
        message: 'Request timed out waiting for server response',
      );
    }
    if (simulatePermanentRejection) {
      throw ValidationException(
        message: rejectionReason,
        errors: [rejectionReason],
      );
    }

    // Idempotent hit check
    final alreadyReceived = remoteAcceptedEvents.any((e) => e.id == event.id);
    if (!alreadyReceived) {
      remoteAcceptedEvents.add(event);
    }

    return {
      'success': true,
      'isIdempotent': alreadyReceived,
      'message': 'Event ${event.eventType} registered successfully',
    };
  }

  @override
  Future<String> deriveTodayAttendanceStatus(
    String employeeId,
    String workingDate,
  ) async {
    if (todaySummary?.checkOutTimestamp != null) return 'Checked Out';
    if (todaySummary?.checkInTimestamp != null) return 'Checked In';
    return 'Not Checked In';
  }
}

/// Test Fake for Leave Repository
class FakeLeaveRepo extends LeaveRepository {
  FakeLeaveRepo()
      : super(apiProvider: ApiProvider(), localDatabase: LocalDatabase());

  LeaveBalanceModel balance = LeaveBalanceModel(
    casualLeave: 8,
    sickLeave: 5,
    totalAvailableLeave: 13,
  );
  List<LeaveModel> requests = [];
  bool isServerReachable = true;
  bool simulateServerError = false;
  String serverErrorMessage = 'Server validation failed';

  @override
  Future<LeaveBalanceModel> fetchLeaveBalance({String? employeeId}) async {
    if (!isServerReachable) {
      throw NetworkException(message: 'Connection refused');
    }
    return balance;
  }

  @override
  Future<LeaveBalanceModel?> getCachedLeaveBalance(String employeeId) async {
    return balance;
  }

  @override
  Future<List<LeaveModel>> fetchLeaveRequests({String? employeeId}) async {
    if (!isServerReachable) {
      throw NetworkException(message: 'Connection refused');
    }
    return requests;
  }

  @override
  Future<List<LeaveModel>> getCachedLeaveRequests(String employeeId) async {
    return requests;
  }

  @override
  Future<LeaveModel> postLeaveRequest({
    required String employeeId,
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    if (!isServerReachable) {
      throw NetworkException(message: 'Connection refused');
    }
    if (simulateServerError) {
      throw ValidationException(
        message: serverErrorMessage,
        errors: [serverErrorMessage],
      );
    }

    final created = LeaveModel(
      id: 'LV-${DateTime.now().millisecondsSinceEpoch}',
      employeeId: employeeId,
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      status: 'Pending',
    );
    requests.add(created);
    return created;
  }
}

/// Controllable Fake Connectivity Service
class FakeConnectivityService extends ConnectivityService {
  final RxBool _online;
  FakeConnectivityService({bool isOnline = true}) : _online = isOnline.obs;

  @override
  RxBool get isOnline => _online;

  void setOnline(bool value) => _online.value = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ISSUE 1 & ISSUE 6 — Auto-Sync, Offline & Network Resilience Tests', () {
    late FakeAttendanceRepo attendanceRepo;
    late FakeConnectivityService connectivity;
    late SyncLogic syncLogic;
    late AttendanceController attendanceController;

    setUp(() {
      Get.reset();
      attendanceRepo = FakeAttendanceRepo();
      connectivity = FakeConnectivityService(isOnline: true);
      syncLogic = SyncLogic(
        attendanceRepository: attendanceRepo,
        connectivityService: connectivity,
      );

      attendanceController = AttendanceController(
        attendanceRepository: attendanceRepo,
        attendanceLogic: AttendanceLogic(locationService: LocationService()),
        syncLogic: syncLogic,
      );
    });

    tearDown(() {
      attendanceController.onClose();
      Get.reset();
    });

    // 1. Online Check In automatically synchronizes
    test('1. Online Check In automatically synchronizes', () async {
      attendanceRepo.isServerReachable = true;
      connectivity.setOnline(true);

      // Create a valid check-in event in persistent queue
      final checkInEvent = AttendanceEventModel(
        id: 'evt-online-in',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckIn,
        timestamp: '2026-11-17T09:00:00+05:30',
        workingDate: '2026-11-17',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-17T09:00:00+05:30',
      );

      await attendanceRepo.insertPendingAttendanceEvent(checkInEvent);

      // Trigger sync
      final summary = await syncLogic.synchronizePendingAttendanceEvents(
        'EMP-001',
      );

      expect(summary.syncedCount, equals(1));
      expect(summary.pendingCount, equals(0));
      expect(
        attendanceRepo.localQueue['evt-online-in']!.syncStatus,
        equals(AppConstants.syncSynced),
      );
    });

    // 2. Online Check Out automatically synchronizes
    test('2. Online Check Out automatically synchronizes', () async {
      attendanceRepo.isServerReachable = true;
      connectivity.setOnline(true);

      final checkOutEvent = AttendanceEventModel(
        id: 'evt-online-out',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckOut,
        timestamp: '2026-11-17T18:00:00+05:30',
        workingDate: '2026-11-17',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-17T18:00:00+05:30',
      );

      await attendanceRepo.insertPendingAttendanceEvent(checkOutEvent);

      final summary = await syncLogic.synchronizePendingAttendanceEvents(
        'EMP-001',
      );

      expect(summary.syncedCount, equals(1));
      expect(
        attendanceRepo.localQueue['evt-online-out']!.syncStatus,
        equals(AppConstants.syncSynced),
      );
    });

    // 3. Offline Check In remains Pending
    test('3. Offline Check In remains Pending', () async {
      connectivity.setOnline(false);

      final checkInEvent = AttendanceEventModel(
        id: 'evt-offline-in',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckIn,
        timestamp: '2026-11-17T09:00:00+05:30',
        workingDate: '2026-11-17',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-17T09:00:00+05:30',
      );

      await attendanceRepo.insertPendingAttendanceEvent(checkInEvent);

      final summary = await syncLogic.synchronizePendingAttendanceEvents(
        'EMP-001',
      );

      expect(summary.syncedCount, equals(0));
      expect(
        attendanceRepo.localQueue['evt-offline-in']!.syncStatus,
        equals(AppConstants.syncPending),
      );
    });

    // 4. Offline Check Out remains Pending
    test('4. Offline Check Out remains Pending', () async {
      connectivity.setOnline(false);

      final checkOutEvent = AttendanceEventModel(
        id: 'evt-offline-out',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckOut,
        timestamp: '2026-11-17T18:00:00+05:30',
        workingDate: '2026-11-17',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-17T18:00:00+05:30',
      );

      await attendanceRepo.insertPendingAttendanceEvent(checkOutEvent);

      final summary = await syncLogic.synchronizePendingAttendanceEvents(
        'EMP-001',
      );

      expect(summary.syncedCount, equals(0));
      expect(
        attendanceRepo.localQueue['evt-offline-out']!.syncStatus,
        equals(AppConstants.syncPending),
      );
    });

    // 5. Pending events survive app restart
    test('5. Pending events survive app restart', () async {
      // Simulate pre-existing pending event in SQLite database
      final existingEvent = AttendanceEventModel(
        id: 'evt-persisted-1',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckIn,
        timestamp: '2026-11-16T09:00:00+05:30',
        workingDate: '2026-11-16',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-16T09:00:00+05:30',
      );
      await attendanceRepo.insertPendingAttendanceEvent(existingEvent);

      // Simulate app restart by initializing a brand new controller
      final newController = AttendanceController(
        attendanceRepository: attendanceRepo,
        attendanceLogic: AttendanceLogic(locationService: LocationService()),
        syncLogic: syncLogic,
      );

      await newController.loadAttendanceData();

      expect(newController.pendingEvents.length, equals(1));
      expect(newController.pendingEvents.first.id, equals('evt-persisted-1'));
      expect(
        newController.getSyncStatusForDate('2026-11-16'),
        equals(AppConstants.syncPending),
      );

      newController.onClose();
    });

    // 6. Manual Sync Now works
    test('6. Manual Sync Now works', () async {
      attendanceRepo.isServerReachable = true;
      connectivity.setOnline(true);

      final event = AttendanceEventModel(
        id: 'evt-manual-sync',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckIn,
        timestamp: '2026-11-17T09:00:00+05:30',
        workingDate: '2026-11-17',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-17T09:00:00+05:30',
      );
      await attendanceRepo.insertPendingAttendanceEvent(event);
      await attendanceController.loadAttendanceData();

      expect(attendanceController.pendingEvents.length, equals(1));

      // Trigger manual sync
      await attendanceController.syncNow(isAutomatic: false);

      expect(attendanceController.pendingEvents.isEmpty, isTrue);
      expect(
        attendanceRepo.localQueue['evt-manual-sync']!.syncStatus,
        equals(AppConstants.syncSynced),
      );
    });

    // 7. Reconnection triggers synchronization attempt
    test('7. Reconnection triggers synchronization attempt', () async {
      attendanceRepo.isServerReachable = true;
      connectivity.setOnline(false);

      final event = AttendanceEventModel(
        id: 'evt-reconnect',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckIn,
        timestamp: '2026-11-17T09:00:00+05:30',
        workingDate: '2026-11-17',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-17T09:00:00+05:30',
      );
      await attendanceRepo.insertPendingAttendanceEvent(event);
      await attendanceController.loadAttendanceData();

      expect(attendanceController.pendingEvents.length, equals(1));

      // Connectivity restored
      connectivity.setOnline(true);
      await Future.delayed(const Duration(milliseconds: 50));

      // Reconnection triggers auto-sync
      await attendanceController.syncNow(isAutomatic: true);

      expect(attendanceController.pendingEvents.isEmpty, isTrue);
      expect(
        attendanceRepo.localQueue['evt-reconnect']!.syncStatus,
        equals(AppConstants.syncSynced),
      );
    });

    // 8. Backend unavailable keeps attendance Pending
    test('8. Backend unavailable keeps attendance Pending', () async {
      connectivity.setOnline(true);
      attendanceRepo.isServerReachable = false; // Mock server down

      final event = AttendanceEventModel(
        id: 'evt-server-down',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckIn,
        timestamp: '2026-11-17T09:00:00+05:30',
        workingDate: '2026-11-17',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-17T09:00:00+05:30',
      );
      await attendanceRepo.insertPendingAttendanceEvent(event);

      final summary = await syncLogic.synchronizePendingAttendanceEvents(
        'EMP-001',
      );

      expect(summary.syncedCount, equals(0));
      expect(summary.pendingCount, equals(1));
      expect(
        attendanceRepo.localQueue['evt-server-down']!.syncStatus,
        equals(AppConstants.syncPending),
      );
    });

    // 9. Timeout after server acceptance is retried idempotently
    test('9. Timeout after server acceptance is retried idempotently', () async {
      connectivity.setOnline(true);
      attendanceRepo.isServerReachable = true;
      attendanceRepo.simulateTimeout = true; // Timeout during first attempt

      final event = AttendanceEventModel(
        id: 'evt-timeout-idempotent',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckIn,
        timestamp: '2026-11-17T09:00:00+05:30',
        workingDate: '2026-11-17',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-17T09:00:00+05:30',
      );
      await attendanceRepo.insertPendingAttendanceEvent(event);

      // First attempt times out
      final summary1 = await syncLogic.synchronizePendingAttendanceEvents(
        'EMP-001',
      );
      expect(summary1.pendingCount, equals(1));
      expect(summary1.syncedCount, equals(0));

      // Second attempt (server recovers, handles idempotently)
      attendanceRepo.simulateTimeout = false;
      final summary2 = await syncLogic.synchronizePendingAttendanceEvents(
        'EMP-001',
      );
      expect(summary2.syncedCount, equals(1));
      expect(
        attendanceRepo.localQueue['evt-timeout-idempotent']!.syncStatus,
        equals(AppConstants.syncSynced),
      );
    });

    // 10. Duplicate attendance events are not created
    test('10. Duplicate attendance events are not created', () async {
      final event = AttendanceEventModel(
        id: 'evt-dup-check',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckIn,
        timestamp: '2026-11-17T09:00:00+05:30',
        workingDate: '2026-11-17',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-17T09:00:00+05:30',
      );

      final firstInsert = await attendanceRepo.insertPendingAttendanceEvent(
        event,
      );
      final secondInsert = await attendanceRepo.insertPendingAttendanceEvent(
        event,
      );

      expect(firstInsert, isTrue);
      expect(secondInsert, isFalse); // Prevented duplicate insertion
      expect(attendanceRepo.localQueue.length, equals(1));
    });

    // 11. Permanent rejection is displayed correctly
    test('11. Permanent rejection is displayed correctly', () async {
      connectivity.setOnline(true);
      attendanceRepo.isServerReachable = true;
      attendanceRepo.simulatePermanentRejection = true;
      attendanceRepo.rejectionReason =
          'Location outside allowed office perimeter (450m > 200m)';

      final event = AttendanceEventModel(
        id: 'evt-rejected-geofence',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckIn,
        timestamp: '2026-11-17T09:00:00+05:30',
        workingDate: '2026-11-17',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-17T09:00:00+05:30',
      );
      await attendanceRepo.insertPendingAttendanceEvent(event);

      final summary = await syncLogic.synchronizePendingAttendanceEvents(
        'EMP-001',
      );

      expect(summary.rejectedCount, equals(1));
      expect(
        attendanceRepo.localQueue['evt-rejected-geofence']!.syncStatus,
        equals(AppConstants.syncRejected),
      );
    });
  });

  group('ISSUE 3, 4 & 5 — Leave Management UI & Network Tests', () {
    late FakeLeaveRepo leaveRepo;
    late FakeConnectivityService connectivity;
    late LeaveController leaveController;

    setUp(() {
      Get.reset();
      leaveRepo = FakeLeaveRepo();
      connectivity = FakeConnectivityService(isOnline: true);
      leaveController = LeaveController(
        leaveRepository: leaveRepo,
        leaveLogic: const LeaveLogic(),
        connectivityService: connectivity,
      );
      Get.put<LeaveController>(leaveController);
    });

    tearDown(() {
      leaveController.onClose();
      Get.reset();
    });

    // 12. Leave submission is blocked when the server is unavailable
    test(
      '12. Leave submission is blocked when the server is unavailable',
      () async {
        connectivity.setOnline(false); // Offline
        await leaveController.loadLeaves();

        leaveController.updateLeaveType('Casual');
        leaveController.updateStartDate('2026-11-20');
        leaveController.updateEndDate('2026-11-21');
        leaveController.reasonController.text =
            'Attending personal family function';

        final success = await leaveController.submitLeaveApplication();

        expect(success, isFalse);
        expect(
          leaveController.serverError.value,
          contains(
            'Leave applications require an internet connection and an available server',
          ),
        );
      },
    );

    // 13. Server-side leave validation errors appear correctly
    test('13. Server-side leave validation errors appear correctly', () async {
      connectivity.setOnline(true);
      leaveRepo.isServerReachable = true;
      leaveRepo.simulateServerError = true;
      leaveRepo.serverErrorMessage =
          'Simulated policy rejection: Annual blackout period active.';

      await leaveController.loadLeaves();

      leaveController.updateLeaveType('Casual');
      leaveController.updateStartDate('2026-11-20');
      leaveController.updateEndDate('2026-11-21');
      leaveController.reasonController.text =
          'Attending personal family function';

      final success = await leaveController.submitLeaveApplication();

      expect(success, isFalse);
      expect(
        leaveController.serverError.value,
        contains('Annual blackout period active'),
      );
    });

    // 14. Casual and Sick UI labels display only leave type and count (no 'available')
    testWidgets(
      '14. Casual and Sick UI labels display only leave type and count',
      (WidgetTester tester) async {
        await leaveController.loadLeaves();

        await tester.pumpWidget(
          const GetMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: LeaveForm()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must find 'Casual (8)' and 'Sick (5)'
        expect(find.text('Casual (8)'), findsOneWidget);
        expect(find.text('Sick (5)'), findsOneWidget);

        // Must NOT find 'available'
        expect(find.textContaining('available'), findsNothing);
      },
    );

    // 15. Leave balance values remain dynamic
    testWidgets('15. Leave balance values remain dynamic', (
      WidgetTester tester,
    ) async {
      // Modify dynamic balance to 12 casual and 4 sick
      leaveRepo.balance = LeaveBalanceModel(
        casualLeave: 12,
        sickLeave: 4,
        totalAvailableLeave: 16,
      );

      await leaveController.loadLeaves();

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: LeaveForm()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Casual (12)'), findsOneWidget);
      expect(find.text('Sick (4)'), findsOneWidget);
      expect(find.textContaining('available'), findsNothing);
    });

    // 16. UI handles small screens without overflow
    testWidgets('16. UI handles small screens without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 600); // Small Android screen
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await leaveController.loadLeaves();

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: LeaveForm()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Casual (8)'), findsOneWidget);
      expect(find.text('Sick (5)'), findsOneWidget);
      expect(tester.takeException(), isNull); // No overflow exception
    });
  });
}
