import '../data/models/leave_balance_model.dart';

class LeaveLogic {
  LeaveLogic();

  /// Calculates total requested leave days inclusive of start and end date
  int calculateLeaveDays(DateTime startDate, DateTime endDate) {
    if (endDate.isBefore(startDate)) return 0;
    return endDate.difference(startDate).inDays + 1;
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
}
