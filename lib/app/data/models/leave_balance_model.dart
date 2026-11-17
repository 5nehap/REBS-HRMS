class LeaveBalanceModel {
  final int casualLeave;
  final int sickLeave;
  final int totalAvailableLeave;

  LeaveBalanceModel({
    required this.casualLeave,
    required this.sickLeave,
    required this.totalAvailableLeave,
  });

  factory LeaveBalanceModel.fromJson(Map<String, dynamic> json) {
    final casual =
        json['casual_leave'] as int? ??
        json['casualLeave'] as int? ??
        json['casual'] as int? ??
        0;
    final sick =
        json['sick_leave'] as int? ??
        json['sickLeave'] as int? ??
        json['sick'] as int? ??
        0;
    final total =
        json['total_available_leave'] as int? ??
        json['totalAvailableLeave'] as int? ??
        json['total'] as int? ??
        (casual + sick);

    return LeaveBalanceModel(
      casualLeave: casual,
      sickLeave: sick,
      totalAvailableLeave: total,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'casual_leave': casualLeave,
      'sick_leave': sickLeave,
      'total_available_leave': totalAvailableLeave,
    };
  }

  LeaveBalanceModel copyWith({
    int? casualLeave,
    int? sickLeave,
    int? totalAvailableLeave,
  }) {
    return LeaveBalanceModel(
      casualLeave: casualLeave ?? this.casualLeave,
      sickLeave: sickLeave ?? this.sickLeave,
      totalAvailableLeave: totalAvailableLeave ?? this.totalAvailableLeave,
    );
  }
}
