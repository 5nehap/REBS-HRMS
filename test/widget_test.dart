import 'package:flutter_test/flutter_test.dart';
import 'package:rebs_hrms/main.dart';

void main() {
  testWidgets('App initialization and placeholder screen load test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RebsHrmsApp());
    await tester.pumpAndSettle();

    // Verify that Dashboard title is present
    expect(find.text('REBS HRMS Dashboard'), findsOneWidget);

    // Verify placeholder cards are present
    expect(find.text("Today's Attendance"), findsOneWidget);
    expect(find.text('Leave Balances'), findsOneWidget);
  });
}
