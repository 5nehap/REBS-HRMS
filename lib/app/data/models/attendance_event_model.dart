class AttendanceEventModel {
  final String id; // Unique event ID (UUID)
  final String employeeId;
  final String eventType; // CHECK_IN or CHECK_OUT
  final String
  timestamp; // ISO 8601 string (preserves original timezone offset)
  final String workingDate; // YYYY-MM-DD
  final double latitude;
  final double longitude;
  final String syncStatus; // PENDING, SYNCED, REJECTED
  final String? syncErrorMessage; // Server rejection reason, if any
  final int retryCount;
  final String createdAt;
  final String? lastAttemptedAt;

  AttendanceEventModel({
    required this.id,
    required this.employeeId,
    required this.eventType,
    required this.timestamp,
    required this.workingDate,
    required this.latitude,
    required this.longitude,
    required this.syncStatus,
    this.syncErrorMessage,
    this.retryCount = 0,
    required this.createdAt,
    this.lastAttemptedAt,
  });

  factory AttendanceEventModel.fromJson(Map<String, dynamic> json) {
    final ts = json['timestamp'] as String? ?? '';
    // Infer workingDate if not explicitly provided
    String wDate =
        json['working_date'] as String? ?? json['workingDate'] as String? ?? '';
    if (wDate.isEmpty && ts.length >= 10) {
      wDate = ts.substring(0, 10);
    }

    return AttendanceEventModel(
      id:
          json['id'] as String? ??
          json['eventId'] as String? ??
          json['event_id'] as String? ??
          '',
      employeeId:
          json['employee_id'] as String? ?? json['employeeId'] as String? ?? '',
      eventType:
          json['event_type'] as String? ?? json['eventType'] as String? ?? '',
      timestamp: ts,
      workingDate: wDate,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      syncStatus:
          json['sync_status'] as String? ??
          json['syncStatus'] as String? ??
          'PENDING',
      syncErrorMessage:
          json['sync_error_message'] as String? ??
          json['syncErrorMessage'] as String? ??
          json['rejection_reason'] as String? ??
          json['rejectionReason'] as String?,
      retryCount:
          (json['retry_count'] as num?)?.toInt() ??
          (json['retryCount'] as num?)?.toInt() ??
          0,
      createdAt:
          json['created_at'] as String? ??
          json['createdAt'] as String? ??
          (ts.isNotEmpty ? ts : DateTime.now().toIso8601String()),
      lastAttemptedAt:
          json['last_attempted_at'] as String? ??
          json['lastAttemptedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'event_type': eventType,
      'timestamp': timestamp,
      'working_date': workingDate,
      'latitude': latitude,
      'longitude': longitude,
      'sync_status': syncStatus,
      'sync_error_message': syncErrorMessage,
      'retry_count': retryCount,
      'created_at': createdAt,
      'last_attempted_at': lastAttemptedAt,
    };
  }

  AttendanceEventModel copyWith({
    String? id,
    String? employeeId,
    String? eventType,
    String? timestamp,
    String? workingDate,
    double? latitude,
    double? longitude,
    String? syncStatus,
    String? syncErrorMessage,
    int? retryCount,
    String? createdAt,
    String? lastAttemptedAt,
  }) {
    return AttendanceEventModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      eventType: eventType ?? this.eventType,
      timestamp: timestamp ?? this.timestamp,
      workingDate: workingDate ?? this.workingDate,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      syncStatus: syncStatus ?? this.syncStatus,
      syncErrorMessage: syncErrorMessage ?? this.syncErrorMessage,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptedAt: lastAttemptedAt ?? this.lastAttemptedAt,
    );
  }
}
