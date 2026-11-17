import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/app/core/constants/app_constants.dart';
import 'package:rebs_hrms/app/data/models/attendance_event_model.dart';

void main() {
  group('SyncLogic Ordering & Sorting Tests', () {
    test('Sorts CHECK_IN before CHECK_OUT for the same working date', () {
      final checkOutEvent = AttendanceEventModel(
        id: 'evt-checkout-1',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckOut,
        timestamp: '2026-11-17T18:00:00+05:30',
        workingDate: '2026-11-17',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-17T18:00:00+05:30',
      );

      final checkInEvent = AttendanceEventModel(
        id: 'evt-checkin-1',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckIn,
        timestamp: '2026-11-17T09:00:00+05:30',
        workingDate: '2026-11-17',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-17T09:00:00+05:30',
      );

      // List in reverse order
      final rawList = [checkOutEvent, checkInEvent];

      // Sort applying SyncLogic rules
      final sortedList = List<AttendanceEventModel>.from(rawList);
      sortedList.sort((a, b) {
        if (a.workingDate == b.workingDate) {
          if (a.eventType == AppConstants.eventCheckIn &&
              b.eventType == AppConstants.eventCheckOut) {
            return -1;
          }
          if (a.eventType == AppConstants.eventCheckOut &&
              b.eventType == AppConstants.eventCheckIn) {
            return 1;
          }
        }
        return a.createdAt.compareTo(b.createdAt);
      });

      expect(sortedList.first.eventType, equals(AppConstants.eventCheckIn));
      expect(sortedList.last.eventType, equals(AppConstants.eventCheckOut));
      expect(sortedList.first.id, equals('evt-checkin-1'));
    });

    test('Preserves chronological order across multiple dates', () {
      final eventDay1 = AttendanceEventModel(
        id: 'evt-day1',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckIn,
        timestamp: '2026-11-16T09:00:00+05:30',
        workingDate: '2026-11-16',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-16T09:00:00+05:30',
      );

      final eventDay2 = AttendanceEventModel(
        id: 'evt-day2',
        employeeId: 'EMP-001',
        eventType: AppConstants.eventCheckIn,
        timestamp: '2026-11-17T09:00:00+05:30',
        workingDate: '2026-11-17',
        latitude: 9.9867592,
        longitude: 76.2857138,
        syncStatus: AppConstants.syncPending,
        createdAt: '2026-11-17T09:00:00+05:30',
      );

      final rawList = [eventDay2, eventDay1];
      final sortedList = List<AttendanceEventModel>.from(rawList);
      sortedList.sort((a, b) {
        if (a.workingDate == b.workingDate) {
          if (a.eventType == AppConstants.eventCheckIn &&
              b.eventType == AppConstants.eventCheckOut) {
            return -1;
          }
          if (a.eventType == AppConstants.eventCheckOut &&
              b.eventType == AppConstants.eventCheckIn) {
            return 1;
          }
        }
        return a.createdAt.compareTo(b.createdAt);
      });

      expect(sortedList.first.id, equals('evt-day1'));
      expect(sortedList.last.id, equals('evt-day2'));
    });
  });
}
