class AppConstants {
  AppConstants._();

  // Attendance Event Types
  static const String eventCheckIn = 'CHECK_IN';
  static const String eventCheckOut = 'CHECK_OUT';

  // Sync Statuses
  static const String syncPending = 'PENDING';
  static const String syncSynced = 'SYNCED';
  static const String syncRejected = 'REJECTED';

  // Leave Statuses
  static const String leavePending = 'PENDING';
  static const String leaveApproved = 'APPROVED';
  static const String leaveRejected = 'REJECTED';

  // Leave Types
  static const String leaveCasual = 'CASUAL';
  static const String leaveSick = 'SICK';
  static const String leaveEarned = 'EARNED';

  // SQLite Tables
  static const String tableEmployees = 'employees';
  static const String tableAttendance = 'attendance';
  static const String tableAttendanceEvents = 'attendance_events';
  static const String tableLeaves = 'leaves';
  static const String tableLeaveBalances = 'leave_balances';
}
