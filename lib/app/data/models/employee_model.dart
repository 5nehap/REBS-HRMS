class EmployeeModel {
  final String id;
  final String name;
  final String department;
  final double officeLatitude;
  final double officeLongitude;
  final String companyTimezone;

  EmployeeModel({
    required this.id,
    required this.name,
    required this.department,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.companyTimezone,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'] as String? ?? json['employee_id'] as String? ?? '',
      name: json['name'] as String? ?? json['employee_name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      officeLatitude:
          (json['office_latitude'] as num?)?.toDouble() ??
          (json['officeLatitude'] as num?)?.toDouble() ??
          0.0,
      officeLongitude:
          (json['office_longitude'] as num?)?.toDouble() ??
          (json['officeLongitude'] as num?)?.toDouble() ??
          0.0,
      companyTimezone:
          json['company_timezone'] as String? ??
          json['companyTimezone'] as String? ??
          'UTC',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'department': department,
      'office_latitude': officeLatitude,
      'office_longitude': officeLongitude,
      'company_timezone': companyTimezone,
    };
  }

  EmployeeModel copyWith({
    String? id,
    String? name,
    String? department,
    double? officeLatitude,
    double? officeLongitude,
    String? companyTimezone,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      department: department ?? this.department,
      officeLatitude: officeLatitude ?? this.officeLatitude,
      officeLongitude: officeLongitude ?? this.officeLongitude,
      companyTimezone: companyTimezone ?? this.companyTimezone,
    );
  }
}
