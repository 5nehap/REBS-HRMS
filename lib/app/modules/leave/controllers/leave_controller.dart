import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/leave_balance_model.dart';
import '../../../data/models/leave_model.dart';
import '../../../data/repositories/leave_repository.dart';
import '../../../logics/leave_logic.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

class LeaveController extends GetxController {
  final LeaveRepository leaveRepository;
  final LeaveLogic leaveLogic;
  final ConnectivityService? connectivityService;

  LeaveController({
    required this.leaveRepository,
    required this.leaveLogic,
    this.connectivityService,
  });

  static const String currentEmployeeId = 'EMP-001';

  // Screen State
  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool isOffline = false.obs;
  final RxString errorMessage = ''.obs;

  // Data
  final Rx<LeaveBalanceModel?> leaveBalance = Rx<LeaveBalanceModel?>(null);
  final RxList<LeaveModel> leaves = <LeaveModel>[].obs;

  // Form Inputs
  final RxString selectedLeaveType = 'Casual'.obs;
  final RxString startDate = ''.obs;
  final RxString endDate = ''.obs;
  final TextEditingController reasonController = TextEditingController();
  final RxInt requestedDays = 0.obs;

  // Form Validation Errors
  final RxString startDateError = ''.obs;
  final RxString endDateError = ''.obs;
  final RxString reasonError = ''.obs;
  final RxString balanceError = ''.obs;
  final RxString overlapError = ''.obs;
  final RxString serverError = ''.obs;

  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void onInit() {
    super.onInit();
    debugPrint('[LeaveController] Initialized for employee $currentEmployeeId');

    if (connectivityService != null) {
      isOffline.value = !connectivityService!.isOnline.value;
      _connectivitySubscription = connectivityService!.isOnline.listen((
        online,
      ) {
        isOffline.value = !online;
        if (online) {
          debugPrint(
            '[LeaveController] Online connection restored. Refreshing leave data...',
          );
          loadLeaves();
        }
      });
    }

    loadLeaves();
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    reasonController.dispose();
    super.onClose();
  }

  // ==========================================
  // DATA LOADING & CACHING
  // ==========================================

  /// Loads leave balances and leave requests history.
  /// Uses SQLite cache for offline resilience and syncs with backend when online.
  Future<void> loadLeaves() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      if (connectivityService != null) {
        isOffline.value = !connectivityService!.isOnline.value;
      }

      // 1. Load cached balance & leave requests from SQLite
      final cachedBalance = await leaveRepository.getCachedLeaveBalance(
        currentEmployeeId,
      );
      if (cachedBalance != null) {
        leaveBalance.value = cachedBalance;
      }

      final cachedLeaves = await leaveRepository.getCachedLeaveRequests(
        currentEmployeeId,
      );
      if (cachedLeaves.isNotEmpty) {
        // Sort newest first
        final sortedCached = cachedLeaves
          ..sort((a, b) => b.startDate.compareTo(a.startDate));
        leaves.assignAll(sortedCached);
      }

      // 2. If online, fetch fresh data from backend and update SQLite cache
      final online = connectivityService?.isOnline.value ?? true;
      if (online) {
        try {
          debugPrint(
            '[LeaveController] Fetching fresh leave data from backend...',
          );
          final remoteBalance = await leaveRepository.fetchLeaveBalance(
            employeeId: currentEmployeeId,
          );
          leaveBalance.value = remoteBalance;

          final remoteLeaves = await leaveRepository.fetchLeaveRequests(
            employeeId: currentEmployeeId,
          );
          final sortedRemote = remoteLeaves
            ..sort((a, b) => b.startDate.compareTo(a.startDate));
          leaves.assignAll(sortedRemote);

          debugPrint(
            '[LeaveController] Remote fetch successful. Balance: Casual=${remoteBalance.casualLeave}, Sick=${remoteBalance.sickLeave}. Requests: ${remoteLeaves.length}',
          );
        } catch (e) {
          debugPrint(
            '[LeaveController] Remote fetch failed (offline/error): $e. Using local SQLite cache.',
          );
          // If no cached data exists, set error
          if (leaveBalance.value == null && leaves.isEmpty) {
            errorMessage.value =
                'Unable to load leave data. Please check your connection.';
          }
        }
      } else {
        debugPrint(
          '[LeaveController] Device is offline. Showing ${leaves.length} cached leave request(s).',
        );
      }

      // Safe fallback balance if still null
      leaveBalance.value ??= LeaveBalanceModel(
        casualLeave: 8,
        sickLeave: 5,
        totalAvailableLeave: 13,
      );
    } catch (e, stack) {
      debugPrint('[LeaveController] Error loading leave data: $e\n$stack');
      errorMessage.value = 'Failed to load leave data. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================
  // FORM INPUT HANDLING & LIVE VALIDATION
  // ==========================================

  /// Updates selected leave type ('Casual' or 'Sick')
  void updateLeaveType(String type) {
    selectedLeaveType.value = type;
    balanceError.value = '';
    serverError.value = '';
    _recalculateDurationAndValidate();
  }

  /// Updates start date and runs date validations
  void updateStartDate(String dateStr) {
    startDate.value = dateStr;
    startDateError.value = '';
    overlapError.value = '';
    serverError.value = '';
    _recalculateDurationAndValidate();
  }

  /// Updates end date and runs date validations
  void updateEndDate(String dateStr) {
    endDate.value = dateStr;
    endDateError.value = '';
    overlapError.value = '';
    serverError.value = '';
    _recalculateDurationAndValidate();
  }

  /// Called when reason text changes
  void onReasonChanged(String text) {
    serverError.value = '';
    if (reasonError.value.isNotEmpty) {
      reasonError.value = leaveLogic.validateReason(text) ?? '';
    }
  }

  /// Recalculates requested calendar days and validates balance and dates
  void _recalculateDurationAndValidate() {
    if (startDate.value.isNotEmpty && endDate.value.isNotEmpty) {
      final days = leaveLogic.calculateLeaveDaysFromString(
        startDate.value,
        endDate.value,
      );
      requestedDays.value = days;

      // Validate end date not before start date
      final endErr = leaveLogic.validateEndDate(
        startDate.value,
        endDate.value,
      );
      endDateError.value = endErr ?? '';

      // Validate balance
      if (leaveBalance.value != null && endErr == null) {
        balanceError.value =
            leaveLogic.validateBalance(
              balance: leaveBalance.value!,
              leaveType: selectedLeaveType.value,
              requestedDays: days,
            ) ??
            '';
      }

      // Validate overlap with active requests
      if (endErr == null) {
        overlapError.value =
            leaveLogic.validateOverlap(
              startDate: startDate.value,
              endDate: endDate.value,
              existingRequests: leaves,
            ) ??
            '';
      }
    } else {
      requestedDays.value = 0;
    }
  }

  /// Validates all form inputs using LeaveLogic business rules
  bool validateForm() {
    serverError.value = '';

    final result = leaveLogic.validateLeaveRequest(
      startDate: startDate.value,
      endDate: endDate.value,
      reason: reasonController.text,
      leaveType: selectedLeaveType.value,
      balance: leaveBalance.value,
      existingRequests: leaves,
    );

    startDateError.value = result.startDateError ?? '';
    endDateError.value = result.endDateError ?? '';
    reasonError.value = result.reasonError ?? '';
    balanceError.value = result.balanceError ?? '';
    overlapError.value = result.overlapError ?? '';

    return result.isValid;
  }

  /// Resets form fields and validation errors
  void resetForm() {
    selectedLeaveType.value = 'Casual';
    startDate.value = '';
    endDate.value = '';
    reasonController.clear();
    requestedDays.value = 0;
    startDateError.value = '';
    endDateError.value = '';
    reasonError.value = '';
    balanceError.value = '';
    overlapError.value = '';
    serverError.value = '';
  }

  // ==========================================
  // LEAVE SUBMISSION (ONLINE ONLY)
  // ==========================================

  /// Submits the leave request.
  /// Explicit requirement: Online only, no offline queuing.
  Future<bool> submitLeaveApplication() async {
    // 1. Prevent duplicate submission while in flight
    if (isSubmitting.value) {
      debugPrint(
        '[LeaveController] Submission already in progress. Ignoring tap.',
      );
      return false;
    }

    // 2. Validate client-side inputs with business rules
    final isValid = validateForm();
    if (!isValid) {
      debugPrint('[LeaveController] Client-side form validation failed.');
      return false;
    }

    // 3. Online connectivity check
    final online = connectivityService?.isOnline.value ?? true;
    if (!online) {
      debugPrint(
        '[LeaveController] Offline submission attempt blocked by policy.',
      );
      final msg = NetworkErrorHandler.getLeaveErrorMessage(
        NetworkException(message: 'Offline'),
      );
      serverError.value = msg;
      _showErrorSnackbar(
        title: 'Submission Unavailable',
        message: msg,
      );
      return false;
    }

    isSubmitting.value = true;
    serverError.value = '';

    try {
      debugPrint(
        '[LeaveController] Submitting leave request to POST /leave/requests...',
      );

      // 4. Submit to backend API
      final createdLeave = await leaveRepository.postLeaveRequest(
        employeeId: currentEmployeeId,
        leaveType: selectedLeaveType.value,
        startDate: startDate.value,
        endDate: endDate.value,
        reason: reasonController.text.trim(),
      );

      debugPrint(
        '[LeaveController] Leave submitted successfully with ID: ${createdLeave.id}',
      );

      // 5. Refresh leave balance and request list from backend
      await loadLeaves();

      // 6. Update DashboardController if registered
      if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().loadDashboardData();
      }

      // 7. Reset form state
      resetForm();

      _showSuccessSnackbar(
        title: 'Leave Submitted',
        message: 'Your leave application has been submitted successfully.',
      );

      return true;
    } on ValidationException catch (e) {
      debugPrint('[LeaveController] Server Validation Exception (422): $e');
      final errorMsg = NetworkErrorHandler.getLeaveErrorMessage(e);
      serverError.value = errorMsg;
      _showErrorSnackbar(title: 'Validation Error', message: errorMsg);
      return false;
    } on NetworkException catch (e) {
      debugPrint('[LeaveController] Network Exception: $e');
      final errorMsg = NetworkErrorHandler.getLeaveErrorMessage(e);
      serverError.value = errorMsg;
      _showErrorSnackbar(
        title: 'Submission Unavailable',
        message: errorMsg,
      );
      return false;
    } on ApiException catch (e) {
      debugPrint('[LeaveController] API Exception: $e');
      final errorMsg = NetworkErrorHandler.getLeaveErrorMessage(e);
      serverError.value = errorMsg;
      _showErrorSnackbar(title: 'Submission Error', message: errorMsg);
      return false;
    } catch (e, stack) {
      debugPrint(
        '[LeaveController] Unexpected error submitting leave: $e\n$stack',
      );
      final errorMsg = NetworkErrorHandler.getLeaveErrorMessage(e);
      serverError.value = errorMsg;
      _showErrorSnackbar(title: 'Submission Error', message: errorMsg);
      return false;
    } finally {
      isSubmitting.value = false;
    }
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
}
