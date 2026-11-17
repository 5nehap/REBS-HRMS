import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../config/office_config.dart';

class LocationService extends GetxService {
  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
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
