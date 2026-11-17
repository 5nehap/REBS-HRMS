import 'package:geolocator/geolocator.dart';
export 'package:geolocator/geolocator.dart' show Position;
import '../core/services/location_service.dart';

class AttendanceValidationResult {
  final bool isValid;
  final String? errorMessage;
  final double? distanceMeters;

  AttendanceValidationResult({
    required this.isValid,
    this.errorMessage,
    this.distanceMeters,
  });
}

class AttendanceLogic {
  final LocationService locationService;

  AttendanceLogic({required this.locationService});

  /// Obtains device location via LocationService
  Future<Position?> getCurrentPosition() async {
    return await locationService.getCurrentPosition();
  }

  /// Obtains detailed device position and permission status
  Future<LocationResult> determinePosition() async {
    return await locationService.determinePosition();
  }

  /// Validates whether the user's location satisfies office geofence requirements (within 200m)
  bool canMarkAttendance(double latitude, double longitude) {
    return locationService.isWithinOfficeGeofence(latitude, longitude);
  }

  /// Calculates distance from office in metres
  double getDistanceFromOffice(double latitude, double longitude) {
    return locationService.calculateDistanceToOffice(latitude, longitude);
  }

  /// Validates attendance location from a Position object
  AttendanceValidationResult validateAttendanceLocation(Position? position) {
    if (position == null) {
      return AttendanceValidationResult(
        isValid: false,
        errorMessage:
            'Unable to acquire GPS coordinates. Please ensure location services are enabled and permissions are granted.',
      );
    }
    return validateLocation(position.latitude, position.longitude);
  }

  /// Validates attendance location and returns detailed result
  AttendanceValidationResult validateLocation(
    double latitude,
    double longitude,
  ) {
    final distance = getDistanceFromOffice(latitude, longitude);
    final isWithin = canMarkAttendance(latitude, longitude);

    if (!isWithin) {
      return AttendanceValidationResult(
        isValid: false,
        distanceMeters: distance,
        errorMessage:
            'You are ${distance.toStringAsFixed(1)}m away from the office. You must be within 200m to mark attendance.',
      );
    }

    return AttendanceValidationResult(isValid: true, distanceMeters: distance);
  }
}
