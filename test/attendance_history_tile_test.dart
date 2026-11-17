import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/app/core/constants/app_constants.dart';
import 'package:rebs_hrms/app/data/models/attendance_model.dart';
import 'package:rebs_hrms/app/modules/attendance/widgets/attendance_history_tile.dart';

void main() {
  group('AttendanceHistoryTile Overflow and Layout Tests', () {
    testWidgets('Renders properly without overflow on normal dimensions', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final attendance = AttendanceModel(
        id: 'ATT-1',
        employeeId: 'EMP-001',
        workingDate: '2026-11-17',
        checkInTimestamp: '2026-11-17T09:00:00+05:30',
        checkOutTimestamp: '2026-11-17T18:00:00+05:30',
        attendanceStatus: 'Present',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: AttendanceHistoryTile(
                attendance: attendance,
                syncStatus: AppConstants.syncPending,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026-11-17'), findsOneWidget);
      expect(find.text('Pending Sync'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders properly on narrow device screen (width: 300)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final attendance = AttendanceModel(
        id: 'ATT-1',
        employeeId: 'EMP-001',
        workingDate: '2026-11-17',
        checkInTimestamp: '2026-11-17T09:00:00+05:30',
        checkOutTimestamp: null,
        attendanceStatus: 'Present',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: AttendanceHistoryTile(
                attendance: attendance,
                syncStatus: AppConstants.syncPending,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026-11-17'), findsOneWidget);
      expect(find.text('Pending Sync'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders with large text scale factor without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final attendance = AttendanceModel(
        id: 'ATT-1',
        employeeId: 'EMP-001',
        workingDate: '2026-11-17',
        checkInTimestamp: '2026-11-17T09:00:00+05:30',
        checkOutTimestamp: '2026-11-17T18:00:00+05:30',
        attendanceStatus: 'Present',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: SizedBox(
                width: 360,
                child: AttendanceHistoryTile(
                  attendance: attendance,
                  syncStatus: AppConstants.syncPending,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026-11-17'), findsOneWidget);
      expect(find.text('Pending Sync'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders Synced status chip correctly', (
      WidgetTester tester,
    ) async {
      final attendance = AttendanceModel(
        id: 'ATT-14',
        employeeId: 'EMP-001',
        workingDate: '2026-11-14',
        checkInTimestamp: '2026-11-14T09:02:15+05:30',
        checkOutTimestamp: '2026-11-14T18:05:40+05:30',
        attendanceStatus: 'Present',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceHistoryTile(
              attendance: attendance,
              syncStatus: AppConstants.syncSynced,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026-11-14'), findsOneWidget);
      expect(find.text('Synced'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
