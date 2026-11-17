class AttendanceModel {
  final String id;
  final String employeeId;
  final String workingDate; // YYYY-MM-DD
  final String? checkInTimestamp; // ISO 8601 string
  final String? checkOutTimestamp; // ISO 8601 string
  final String attendanceStatus; // Present, Absent, Half-Day

  AttendanceModel({
    required this.id,
    required this.employeeId,
    required this.workingDate,
    this.checkInTimestamp,
    this.checkOutTimestamp,
    required this.attendanceStatus,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as String? ?? json['attendance_id'] as String? ?? '',
      employeeId:
          json['employee_id'] as String? ?? json['employeeId'] as String? ?? '',
      workingDate:
          json['working_date'] as String? ??
          json['workingDate'] as String? ??
          json['date'] as String? ??
          '',
      checkInTimestamp:
          json['check_in_timestamp'] as String? ??
          json['checkInTimestamp'] as String? ??
          json['check_in_time'] as String?,
      checkOutTimestamp:
          json['check_out_timestamp'] as String? ??
          json['checkOutTimestamp'] as String? ??
          json['check_out_time'] as String?,
      attendanceStatus:
          json['attendance_status'] as String? ??
          json['attendanceStatus'] as String? ??
          json['status'] as String? ??
          'Present',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'working_date': workingDate,
      'check_in_timestamp': checkInTimestamp,
      'check_out_timestamp': checkOutTimestamp,
      'attendance_status': attendanceStatus,
    };
  }

  AttendanceModel copyWith({
    String? id,
    String? employeeId,
    String? workingDate,
    String? checkInTimestamp,
    String? checkOutTimestamp,
    String? attendanceStatus,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      workingDate: workingDate ?? this.workingDate,
      checkInTimestamp: checkInTimestamp ?? this.checkInTimestamp,
      checkOutTimestamp: checkOutTimestamp ?? this.checkOutTimestamp,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
    );
  }
}
