import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drone_academy/screens/competition_timer_screen.dart';

void main() {
  Widget buildCompetitionTimerScreen() {
    return const MaterialApp(
      home: CompetitionTimerScreen(
        competition: {'id': 'comp-1', 'title': 'اختبار مسابقة'},
        traineeDoc: {'id': 'trainee-1', 'displayName': 'متدرب تجريبي'},
      ),
    );
  }

  testWidgets('shows competition title and initial start state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildCompetitionTimerScreen());

    expect(find.text('اختبار مسابقة'), findsOneWidget);
    expect(find.text('00:00:000'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('STOP'), findsNothing);
    expect(find.text('SAVE RESULT'), findsNothing);
  });

  testWidgets('transitions from start to stop to save result', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildCompetitionTimerScreen());

    await tester.tap(find.text('START'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('STOP'), findsOneWidget);
    expect(find.text('START'), findsNothing);

    await tester.tap(find.text('STOP'));
    await tester.pump();

    expect(find.text('SAVE RESULT'), findsOneWidget);
    expect(find.text('STOP'), findsNothing);
  });
}
