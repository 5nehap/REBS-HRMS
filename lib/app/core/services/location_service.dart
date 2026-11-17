import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../config/office_config.dart';

enum LocationCheckStatus {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  available,
}

class LocationResult {
  final LocationCheckStatus status;
  final Position? position;
  final String? errorMessage;

  LocationResult({required this.status, this.position, this.errorMessage});

  bool get isSuccess =>
      status == LocationCheckStatus.available && position != null;
}

class LocationService extends GetxService {
  Future<LocationCheckStatus> checkPermissionStatus() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationCheckStatus.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationCheckStatus.permissionDenied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationCheckStatus.permissionDeniedForever;
    }

    return LocationCheckStatus.available;
  }

  Future<bool> checkPermission() async {
    final status = await checkPermissionStatus();
    return status == LocationCheckStatus.available;
  }

  Future<LocationResult> determinePosition() async {
    final status = await checkPermissionStatus();
    if (status == LocationCheckStatus.serviceDisabled) {
      return LocationResult(
        status: status,
        errorMessage:
            'Location services are disabled on your device. Please enable GPS in settings.',
      );
    }
    if (status == LocationCheckStatus.permissionDenied) {
      return LocationResult(
        status: status,
        errorMessage:
            'Location permission was denied. Location access is required for attendance.',
      );
    }
    if (status == LocationCheckStatus.permissionDeniedForever) {
      return LocationResult(
        status: status,
        errorMessage:
            'Location permissions are permanently denied. Please enable them in app settings.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationResult(
        status: LocationCheckStatus.available,
        position: position,
      );
    } catch (e) {
      return LocationResult(
        status: LocationCheckStatus.available,
        errorMessage:
            'Unable to acquire GPS location. Please check signal and try again.',
      );
    }
  }

  Future<Position?> getCurrentPosition() async {
    final result = await determinePosition();
    return result.position;
  }

  double calculateDistanceToOffice(double latitude, double longitude) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      OfficeConfig.officeLatitude,
      OfficeConfig.officeLongitude,
    );
  }

  bool isWithinOfficeGeofence(double latitude, double longitude) {
    final distance = calculateDistanceToOffice(latitude, longitude);
    return distance <= OfficeConfig.geofenceRadiusInMeters;
  }
}
