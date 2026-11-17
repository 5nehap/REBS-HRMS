import '../core/services/location_service.dart';

class AttendanceLogic {
  final LocationService locationService;

  AttendanceLogic({required this.locationService});

  /// Validates whether the user's location satisfies office geofence requirements (within 200m)
  bool canMarkAttendance(double latitude, double longitude) {
    return locationService.isWithinOfficeGeofence(latitude, longitude);
  }

  /// Calculates distance from office
  double getDistanceFromOffice(double latitude, double longitude) {
    return locationService.calculateDistanceToOffice(latitude, longitude);
  }
}
