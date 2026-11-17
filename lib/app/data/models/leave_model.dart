class LeaveModel {
  final String id; // Leave request ID
  final String employeeId;
  final String leaveType; // Casual or Sick
  final String startDate; // YYYY-MM-DD
  final String endDate; // YYYY-MM-DD
  final String reason;
  final String status; // Pending, Approved, Rejected

  LeaveModel({
    required this.id,
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
  });

  /// Calculates calendar days requested (inclusive of start and end date)
  int get requestedDays {
    final start = DateTime.tryParse(startDate);
    final end = DateTime.tryParse(endDate);
    if (start == null || end == null) return 0;
    if (end.isBefore(start)) return 0;
    return end.difference(start).inDays + 1;
  }

  factory LeaveModel.fromJson(Map<String, dynamic> json) {
    return LeaveModel(
      id:
          json['id'] as String? ??
          json['leave_id'] as String? ??
          json['leaveId'] as String? ??
          '',
      employeeId:
          json['employee_id'] as String? ?? json['employeeId'] as String? ?? '',
      leaveType:
          json['leave_type'] as String? ?? json['leaveType'] as String? ?? '',
      startDate:
          json['start_date'] as String? ?? json['startDate'] as String? ?? '',
      endDate: json['end_date'] as String? ?? json['endDate'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'Pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'leave_type': leaveType,
      'start_date': startDate,
      'end_date': endDate,
      'reason': reason,
      'status': status,
    };
  }

  LeaveModel copyWith({
    String? id,
    String? employeeId,
    String? leaveType,
    String? startDate,
    String? endDate,
    String? reason,
    String? status,
  }) {
    return LeaveModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
    );
  }
}
