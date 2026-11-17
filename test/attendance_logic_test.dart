import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/app/core/config/office_config.dart';
import 'package:rebs_hrms/app/core/services/location_service.dart';
import 'package:rebs_hrms/app/logics/attendance_logic.dart';

void main() {
  group('AttendanceLogic Geofence & Location Validation Tests', () {
    final locationService = LocationService();
    final attendanceLogic = AttendanceLogic(locationService: locationService);

    test('Validates position exactly at office coordinates', () {
      final result = attendanceLogic.validateLocation(
        OfficeConfig.officeLatitude,
        OfficeConfig.officeLongitude,
      );
      expect(result.isValid, isTrue);
      expect(result.distanceMeters, lessThanOrEqualTo(200.0));
      expect(result.errorMessage, isNull);
    });

    test('Rejects position far away from office (e.g. +1.0 deg offset)', () {
      final result = attendanceLogic.validateLocation(
        OfficeConfig.officeLatitude + 1.0,
        OfficeConfig.officeLongitude + 1.0,
      );
      expect(result.isValid, isFalse);
      expect(result.distanceMeters, greaterThan(200.0));
      expect(result.errorMessage, contains('away from the office'));
    });

    test('validateAttendanceLocation accepts Position object within 200m', () {
      final pos = Position(
        latitude: OfficeConfig.officeLatitude,
        longitude: OfficeConfig.officeLongitude,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final result = attendanceLogic.validateAttendanceLocation(pos);
      expect(result.isValid, isTrue);
      expect(result.distanceMeters, lessThanOrEqualTo(200.0));
      expect(result.errorMessage, isNull);
    });

    test('validateAttendanceLocation rejects Position object outside 200m', () {
      final pos = Position(
        latitude: OfficeConfig.officeLatitude + 0.05,
        longitude: OfficeConfig.officeLongitude + 0.05,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final result = attendanceLogic.validateAttendanceLocation(pos);
      expect(result.isValid, isFalse);
      expect(result.distanceMeters, greaterThan(200.0));
      expect(result.errorMessage, contains('away from the office'));
    });

    test('validateAttendanceLocation gracefully handles null position', () {
      final result = attendanceLogic.validateAttendanceLocation(null);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Unable to acquire GPS coordinates'));
    });
  });
}
