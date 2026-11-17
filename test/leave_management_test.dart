import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rebs_hrms/app/core/errors/api_exception.dart';
import 'package:rebs_hrms/app/core/services/connectivity_service.dart';
import 'package:rebs_hrms/app/data/models/leave_balance_model.dart';
import 'package:rebs_hrms/app/data/models/leave_model.dart';
import 'package:rebs_hrms/app/data/providers/api_provider.dart';
import 'package:rebs_hrms/app/data/providers/local_database.dart';
import 'package:rebs_hrms/app/data/repositories/leave_repository.dart';
import 'package:rebs_hrms/app/logics/leave_logic.dart';
import 'package:rebs_hrms/app/modules/leave/controllers/leave_controller.dart';

/// Test mock implementation of LeaveRepository
class FakeLeaveRepository extends LeaveRepository {
  FakeLeaveRepository()
      : super(apiProvider: ApiProvider(), localDatabase: LocalDatabase());

  LeaveBalanceModel cachedBalance = LeaveBalanceModel(
    casualLeave: 8,
    sickLeave: 5,
    totalAvailableLeave: 13,
  );

  List<LeaveModel> cachedRequests = [
    LeaveModel(
      id: 'LV-CACHED-1',
      employeeId: 'EMP-001',
      leaveType: 'Casual',
      startDate: '2026-11-10',
      endDate: '2026-11-11',
      reason: 'Personal family emergency',
      status: 'Approved',
    ),
  ];

  bool shouldThrowValidation = false;
  String validationErrorMessage = 'Simulated server validation rejection';
  List<String> validationErrors = ['Server rejection: Blackout period active'];

  @override
  Future<LeaveBalanceModel> fetchLeaveBalance({String? employeeId}) async {
    return cachedBalance;
  }

  @override
  Future<List<LeaveModel>> fetchLeaveRequests({String? employeeId}) async {
    return List<LeaveModel>.from(cachedRequests);
  }

  @override
  Future<LeaveBalanceModel?> getCachedLeaveBalance(String employeeId) async {
    return cachedBalance;
  }

  @override
  Future<List<LeaveModel>> getCachedLeaveRequests(String employeeId) async {
    return List<LeaveModel>.from(cachedRequests);
  }

  @override
  Future<LeaveModel> postLeaveRequest({
    required String employeeId,
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    if (shouldThrowValidation) {
      throw ValidationException(
        message: validationErrorMessage,
        errors: validationErrors,
      );
    }

    final newLeave = LeaveModel(
      id: 'LV-NEW-${DateTime.now().millisecondsSinceEpoch}',
      employeeId: employeeId,
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      status: 'Pending',
    );

    cachedRequests.add(newLeave);

    // Deduct balance
    final days = LeaveLogic().calculateLeaveDays(
      DateTime.parse(startDate),
      DateTime.parse(endDate),
    );
    if (leaveType.toUpperCase() == 'CASUAL') {
      cachedBalance = cachedBalance.copyWith(
        casualLeave: cachedBalance.casualLeave - days,
        totalAvailableLeave: cachedBalance.totalAvailableLeave - days,
      );
    } else {
      cachedBalance = cachedBalance.copyWith(
        sickLeave: cachedBalance.sickLeave - days,
        totalAvailableLeave: cachedBalance.totalAvailableLeave - days,
      );
    }

    return newLeave;
  }
}

/// Fake connectivity service
class FakeConnectivityService extends ConnectivityService {
  final RxBool _online;

  FakeConnectivityService({bool isOnline = true}) : _online = isOnline.obs;

  @override
  RxBool get isOnline => _online;

  void setOnline(bool value) {
    _online.value = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const leaveLogic = LeaveLogic();
  const companyDate = '2026-11-17';

  group('Leave Management — Validation & Business Rules Tests', () {
    // 1. Start date before the company date is rejected
    test('1. Start date before company date is rejected', () {
      final error = leaveLogic.validateStartDate(
        '2026-11-16',
        companyDateStr: companyDate,
      );

      expect(error, isNotNull);
      expect(
        error,
        contains('Start date cannot be before current company date'),
      );

      final validSameDay = leaveLogic.validateStartDate(
        '2026-11-17',
        companyDateStr: companyDate,
      );
      expect(validSameDay, isNull);

      final validFutureDay = leaveLogic.validateStartDate(
        '2026-11-18',
        companyDateStr: companyDate,
      );
      expect(validFutureDay, isNull);
    });

    // 2. End date before start date is rejected
    test('2. End date before start date is rejected', () {
      final error = leaveLogic.validateEndDate('2026-11-20', '2026-11-19');

      expect(error, isNotNull);
      expect(error, equals('End date cannot be before start date'));

      final validSameDay = leaveLogic.validateEndDate(
        '2026-11-20',
        '2026-11-20',
      );
      expect(validSameDay, isNull);

      final validFuture = leaveLogic.validateEndDate(
        '2026-11-20',
        '2026-11-22',
      );
      expect(validFuture, isNull);
    });

    // 3. Reason shorter than 10 non-whitespace characters is rejected
    test('3. Reason shorter than 10 non-whitespace characters is rejected', () {
      // 9 non-whitespace characters with whitespace padding
      final error9 = leaveLogic.validateReason('   123456789   ');
      expect(error9, isNotNull);
      expect(
        error9,
        contains('Reason must contain at least 10 non-whitespace characters'),
      );

      final emptyError = leaveLogic.validateReason('          ');
      expect(emptyError, isNotNull);

      // Exactly 10 non-whitespace characters
      final valid10 = leaveLogic.validateReason('  12345 67890  ');
      expect(valid10, isNull);

      // More than 10 non-whitespace characters
      final validDetailed = leaveLogic.validateReason(
        'Attending sister wedding ceremony in hometown',
      );
      expect(validDetailed, isNull);
    });

    // 4. Requested days exceeding leave balance are rejected
    test('4. Requested days exceeding leave balance are rejected', () {
      final balance = LeaveBalanceModel(
        casualLeave: 3,
        sickLeave: 2,
        totalAvailableLeave: 5,
      );

      // Casual: 4 days requested, only 3 available -> rejected
      final casualError = leaveLogic.validateBalance(
        balance: balance,
        leaveType: 'Casual',
        requestedDays: 4,
      );
      expect(casualError, isNotNull);
      expect(
        casualError,
        contains('Requested 4 days exceeds available Casual leave balance of 3'),
      );

      // Casual: 3 days requested, 3 available -> valid
      final casualValid = leaveLogic.validateBalance(
        balance: balance,
        leaveType: 'Casual',
        requestedDays: 3,
      );
      expect(casualValid, isNull);

      // Sick: 3 days requested, only 2 available -> rejected
      final sickError = leaveLogic.validateBalance(
        balance: balance,
        leaveType: 'Sick',
        requestedDays: 3,
      );
      expect(sickError, isNotNull);
      expect(
        sickError,
        contains('Requested 3 days exceeds available Sick leave balance of 2'),
      );

      // Sick: 2 days requested, 2 available -> valid
      final sickValid = leaveLogic.validateBalance(
        balance: balance,
        leaveType: 'Sick',
        requestedDays: 2,
      );
      expect(sickValid, isNull);
    });

    // 5. Overlap with a Pending request is rejected
    test('5. Overlap with a Pending request is rejected', () {
      final existingRequests = [
        LeaveModel(
          id: 'LV-PENDING-1',
          employeeId: 'EMP-001',
          leaveType: 'Casual',
          startDate: '2026-11-20',
          endDate: '2026-11-22',
          reason: 'Existing pending leave application',
          status: 'Pending',
        ),
      ];

      // Overlap range 2026-11-21 to 2026-11-24
      final overlapError = leaveLogic.validateOverlap(
        startDate: '2026-11-21',
        endDate: '2026-11-24',
        existingRequests: existingRequests,
      );

      expect(overlapError, isNotNull);
      expect(
        overlapError,
        contains('Requested dates overlap with an existing Pending leave application'),
      );
    });

    // 6. Overlap with an Approved request is rejected
    test('6. Overlap with an Approved request is rejected', () {
      final existingRequests = [
        LeaveModel(
          id: 'LV-APPROVED-1',
          employeeId: 'EMP-001',
          leaveType: 'Sick',
          startDate: '2026-11-25',
          endDate: '2026-11-27',
          reason: 'Doctor scheduled medical procedure',
          status: 'Approved',
        ),
      ];

      // Exact same dates 2026-11-25 to 2026-11-27
      final overlapExact = leaveLogic.validateOverlap(
        startDate: '2026-11-25',
        endDate: '2026-11-27',
        existingRequests: existingRequests,
      );

      expect(overlapExact, isNotNull);
      expect(
        overlapExact,
        contains('Requested dates overlap with an existing Approved leave application'),
      );
    });

    // 7. Overlap with a Rejected request is permitted
    test('7. Overlap with a Rejected request is permitted', () {
      final existingRequests = [
        LeaveModel(
          id: 'LV-REJECTED-1',
          employeeId: 'EMP-001',
          leaveType: 'Casual',
          startDate: '2026-11-20',
          endDate: '2026-11-22',
          reason: 'Previously rejected leave request',
          status: 'Rejected',
        ),
      ];

      // Exact same dates as rejected request
      final overlap = leaveLogic.validateOverlap(
        startDate: '2026-11-20',
        endDate: '2026-11-22',
        existingRequests: existingRequests,
      );

      // Overlap with a Rejected request must be permitted (null error)
      expect(overlap, isNull);
      expect(
        leaveLogic.hasDateOverlap(
          startDate: '2026-11-20',
          endDate: '2026-11-22',
          existingRequests: existingRequests,
        ),
        isFalse,
      );
    });
  });

  group('LeaveController & API / Offline Integration Tests', () {
    late FakeLeaveRepository repository;
    late FakeConnectivityService connectivity;
    late LeaveController controller;

    setUp(() {
      Get.reset();
      repository = FakeLeaveRepository();
      connectivity = FakeConnectivityService(isOnline: true);
      controller = LeaveController(
        leaveRepository: repository,
        leaveLogic: leaveLogic,
        connectivityService: connectivity,
      );
    });

    tearDown(() {
      controller.onClose();
      Get.reset();
    });

    // 8. Valid leave request can be submitted successfully
    test('8. Valid leave request can be submitted successfully', () async {
      await controller.loadLeaves();

      controller.updateLeaveType('Casual');
      controller.updateStartDate('2026-11-25');
      controller.updateEndDate('2026-11-26'); // 2 calendar days
      controller.reasonController.text = 'Family function attendance in hometown';

      expect(controller.requestedDays.value, equals(2));
      expect(controller.validateForm(), isTrue);

      final success = await controller.submitLeaveApplication();

      expect(success, isTrue);
      expect(controller.isSubmitting.value, isFalse);
      expect(controller.serverError.value, isEmpty);

      // Verify request added to list
      expect(controller.leaves.length, equals(2));
      expect(
        controller.leaves.any((l) => l.startDate == '2026-11-25'),
        isTrue,
      );

      // Verify balance deducted (8 - 2 = 6)
      expect(controller.leaveBalance.value?.casualLeave, equals(6));
    });

    // 9. Server-side validation rejection is displayed
    test('9. Server-side validation rejection is displayed', () async {
      await controller.loadLeaves();

      repository.shouldThrowValidation = true;
      repository.validationErrorMessage = 'Validation failed on server';
      repository.validationErrors = [
        'Simulated policy rejection: Annual blackout period active.',
      ];

      controller.updateLeaveType('Casual');
      controller.updateStartDate('2026-11-25');
      controller.updateEndDate('2026-11-26');
      controller.reasonController.text = 'Family function attendance in hometown';

      final success = await controller.submitLeaveApplication();

      expect(success, isFalse);
      expect(controller.isSubmitting.value, isFalse);
      expect(
        controller.serverError.value,
        contains('Annual blackout period active'),
      );
    });

    // 10. Cached leave requests remain available offline
    test('10. Cached leave requests remain available offline', () async {
      // Set offline mode
      connectivity.setOnline(false);

      await controller.loadLeaves();

      expect(controller.isOffline.value, isTrue);
      expect(controller.leaves.isNotEmpty, isTrue);
      expect(controller.leaves.first.id, equals('LV-CACHED-1'));
      expect(controller.leaves.first.reason, equals('Personal family emergency'));
      expect(controller.leaveBalance.value, isNotNull);
      expect(controller.leaveBalance.value?.casualLeave, equals(8));
      expect(controller.leaveBalance.value?.sickLeave, equals(5));

      // Attempting to submit while offline should be blocked
      controller.updateStartDate('2026-11-28');
      controller.updateEndDate('2026-11-29');
      controller.reasonController.text = 'Valid reason for leave application';

      final submitted = await controller.submitLeaveApplication();
      expect(submitted, isFalse);
      expect(
        controller.serverError.value,
        contains('require an internet connection and an available server'),
      );
    });
  });
}

