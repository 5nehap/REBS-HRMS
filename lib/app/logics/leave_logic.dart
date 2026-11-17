import '../core/utils/date_helper.dart';
import '../data/models/leave_balance_model.dart';
import '../data/models/leave_model.dart';

class LeaveValidationResult {
  final bool isValid;
  final String? startDateError;
  final String? endDateError;
  final String? reasonError;
  final String? balanceError;
  final String? overlapError;
  final String? generalError;

  const LeaveValidationResult({
    required this.isValid,
    this.startDateError,
    this.endDateError,
    this.reasonError,
    this.balanceError,
    this.overlapError,
    this.generalError,
  });

  static const valid = LeaveValidationResult(isValid: true);

  /// Helper to get first available user-friendly error message
  String? get firstError =>
      startDateError ??
      endDateError ??
      reasonError ??
      balanceError ??
      overlapError ??
      generalError;
}

class LeaveLogic {
  const LeaveLogic();

  /// Calculates total requested leave days inclusive of start and end date.
  /// Counts all calendar days including weekends and holidays.
  int calculateLeaveDays(DateTime startDate, DateTime endDate) {
    if (endDate.isBefore(startDate)) return 0;
    return endDate.difference(startDate).inDays + 1;
  }

  /// Calculates leave days from ISO date strings (YYYY-MM-DD).
  int calculateLeaveDaysFromString(String? startDateStr, String? endDateStr) {
    if (startDateStr == null || endDateStr == null) return 0;
    final start = DateHelper.parseDate(startDateStr);
    final end = DateHelper.parseDate(endDateStr);
    if (start == null || end == null) return 0;
    return calculateLeaveDays(start, end);
  }

  /// Returns current company date in the configured company timezone (Asia/Kolkata: UTC+5:30)
  DateTime getCompanyCurrentDate({
    DateTime? referenceTime,
    String timezone = 'Asia/Kolkata',
  }) {
    final now = (referenceTime ?? DateTime.now()).toUtc();
    // Asia/Kolkata company timezone is UTC+05:30
    const kolkataOffset = Duration(hours: 5, minutes: 30);
    final kolkataTime = now.add(kolkataOffset);
    return DateTime(kolkataTime.year, kolkataTime.month, kolkataTime.day);
  }

  /// Returns formatted company current date string (YYYY-MM-DD)
  String getCompanyCurrentDateString({
    DateTime? referenceTime,
    String timezone = 'Asia/Kolkata',
  }) {
    final date = getCompanyCurrentDate(
      referenceTime: referenceTime,
      timezone: timezone,
    );
    return DateHelper.formatDate(date);
  }

  /// Validates start date:
  /// - Must not be empty
  /// - Must not be before current company date
  String? validateStartDate(
    String? startDateStr, {
    String? companyDateStr,
    DateTime? referenceTime,
  }) {
    if (startDateStr == null || startDateStr.trim().isEmpty) {
      return 'Start date is required';
    }

    final start = DateHelper.parseDate(startDateStr);
    if (start == null) {
      return 'Invalid start date format (YYYY-MM-DD)';
    }

    final effectiveCompanyDateStr =
        companyDateStr ??
        getCompanyCurrentDateString(referenceTime: referenceTime);

    // Lexicographical comparison works safely for YYYY-MM-DD
    if (startDateStr.trim().compareTo(effectiveCompanyDateStr) < 0) {
      return 'Start date cannot be before current company date ($effectiveCompanyDateStr)';
    }

    return null;
  }

  /// Validates end date:
  /// - Must not be empty
  /// - Must not be before start date
  String? validateEndDate(String? startDateStr, String? endDateStr) {
    if (endDateStr == null || endDateStr.trim().isEmpty) {
      return 'End date is required';
    }

    final end = DateHelper.parseDate(endDateStr);
    if (end == null) {
      return 'Invalid end date format (YYYY-MM-DD)';
    }

    if (startDateStr != null && startDateStr.trim().isNotEmpty) {
      if (endDateStr.trim().compareTo(startDateStr.trim()) < 0) {
        return 'End date cannot be before start date';
      }
    }

    return null;
  }

  /// Validates reason:
  /// - Must not be empty
  /// - Must contain at least 10 non-whitespace characters
  String? validateReason(String? reason) {
    if (reason == null || reason.trim().isEmpty) {
      return 'Reason is required';
    }

    // Count non-whitespace characters only
    final nonWhitespaceCount = reason.replaceAll(RegExp(r'\s'), '').length;
    if (nonWhitespaceCount < 10) {
      return 'Reason must contain at least 10 non-whitespace characters (currently $nonWhitespaceCount)';
    }

    return null;
  }

  /// Validates whether the employee has sufficient balance for the requested leave type
  bool hasSufficientBalance({
    required LeaveBalanceModel balance,
    required String leaveType,
    required int requestedDays,
  }) {
    if (requestedDays <= 0) return false;

    switch (leaveType.toUpperCase()) {
      case 'CASUAL':
        return balance.casualLeave >= requestedDays;
      case 'SICK':
        return balance.sickLeave >= requestedDays;
      default:
        return false;
    }
  }

  /// Returns user-friendly balance validation error if requested days exceed available balance
  String? validateBalance({
    required LeaveBalanceModel balance,
    required String leaveType,
    required int requestedDays,
  }) {
    if (requestedDays <= 0) {
      return 'Requested leave duration must be at least 1 day';
    }

    final normalized = leaveType.toUpperCase();
    if (normalized == 'CASUAL') {
      if (requestedDays > balance.casualLeave) {
        return 'Requested $requestedDays days exceeds available Casual leave balance of ${balance.casualLeave}';
      }
    } else if (normalized == 'SICK') {
      if (requestedDays > balance.sickLeave) {
        return 'Requested $requestedDays days exceeds available Sick leave balance of ${balance.sickLeave}';
      }
    } else {
      return 'Invalid leave type. Only "Casual" or "Sick" are allowed';
    }

    return null;
  }

  /// Finds any active (Pending or Approved) leave request that overlaps with requested dates.
  /// Overlap condition: `(StartA <= EndB) && (EndA >= StartB)`
  /// Rejected requests do NOT block new leave applications.
  LeaveModel? findOverlappingRequest({
    required String startDate,
    required String endDate,
    required List<LeaveModel> existingRequests,
  }) {
    for (final request in existingRequests) {
      final status = request.status.toUpperCase();
      // Only Pending and Approved requests block new leave applications
      if (status != 'PENDING' && status != 'APPROVED') {
        continue;
      }

      // Overlap check on date strings YYYY-MM-DD
      final isOverlapping =
          startDate.compareTo(request.endDate) <= 0 &&
          endDate.compareTo(request.startDate) >= 0;

      if (isOverlapping) {
        return request;
      }
    }
    return null;
  }

  /// Checks if any active (Pending or Approved) leave request overlaps with requested dates
  bool hasDateOverlap({
    required String startDate,
    required String endDate,
    required List<LeaveModel> existingRequests,
  }) {
    return findOverlappingRequest(
          startDate: startDate,
          endDate: endDate,
          existingRequests: existingRequests,
        ) !=
        null;
  }

  /// Returns user-friendly overlap error message if dates overlap an active leave request
  String? validateOverlap({
    required String startDate,
    required String endDate,
    required List<LeaveModel> existingRequests,
  }) {
    final overlap = findOverlappingRequest(
      startDate: startDate,
      endDate: endDate,
      existingRequests: existingRequests,
    );

    if (overlap != null) {
      return 'Requested dates overlap with an existing ${overlap.status} leave application (${overlap.startDate} to ${overlap.endDate})';
    }

    return null;
  }

  /// Comprehensive leave request validation combining all rules
  LeaveValidationResult validateLeaveRequest({
    required String? startDate,
    required String? endDate,
    required String? reason,
    required String leaveType,
    required LeaveBalanceModel? balance,
    required List<LeaveModel> existingRequests,
    String? companyDateStr,
    DateTime? referenceTime,
  }) {
    final startError = validateStartDate(
      startDate,
      companyDateStr: companyDateStr,
      referenceTime: referenceTime,
    );
    final endError = validateEndDate(startDate, endDate);
    final reasonErr = validateReason(reason);

    String? balanceErr;
    if (startDate != null &&
        endDate != null &&
        startError == null &&
        endError == null) {
      final days = calculateLeaveDaysFromString(startDate, endDate);
      if (balance != null) {
        balanceErr = validateBalance(
          balance: balance,
          leaveType: leaveType,
          requestedDays: days,
        );
      }
    }

    String? overlapErr;
    if (startDate != null &&
        endDate != null &&
        startError == null &&
        endError == null) {
      overlapErr = validateOverlap(
        startDate: startDate,
        endDate: endDate,
        existingRequests: existingRequests,
      );
    }

    final isValid =
        startError == null &&
        endError == null &&
        reasonErr == null &&
        balanceErr == null &&
        overlapErr == null;

    return LeaveValidationResult(
      isValid: isValid,
      startDateError: startError,
      endDateError: endError,
      reasonError: reasonErr,
      balanceError: balanceErr,
      overlapError: overlapErr,
    );
  }
}
