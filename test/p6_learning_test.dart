import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/app/app_theme.dart';
import 'package:round_ai/core/utils/hospital_clock.dart';
import 'package:round_ai/features/learning/models/teaching_plan.dart';
import 'package:round_ai/features/learning/repository/demo_teaching_repository.dart';
import 'package:round_ai/features/learning/screens/learning_screen.dart';

void main() {
  tearDown(() {
    HospitalClock.runtimeDemoClockIso = null;
  });

  test('P6: TeachingTopic parses bank_count into countLabel', () {
    final TeachingTopic t = TeachingTopic.fromJson(<String, dynamic>{
      'topic': 'Elevated Pulse',
      'topic_key': 'elevated pulse',
      'count': 1,
      'confirmed': 1,
      'differential': 0,
      'bank_count': 5,
    });
    expect(t.bankCount, 5);
    expect(t.countLabel, contains('5 bank questions'));
  });

  test('P6: HospitalClock demo runtime override', () {
    HospitalClock.runtimeDemoClockIso = '2026-09-02T12:00:00.000Z';
    expect(HospitalClock.todayIsoDate(), '2026-09-02');
  });

  testWidgets('P6: Learn topics filter narrows the list', (
    WidgetTester tester,
  ) async {
    final DemoTeachingRepository repo = DemoTeachingRepository(
      clock: () => DateTime.utc(2026, 9, 2, 12),
    );
    // Warm demo plan has topics from PatientWorkspace / demo patients.
    final Result<TeachingPlan> plan = await repo.loadPlan(date: '2026-09-02');
    expect(plan, isA<Ok<TeachingPlan>>());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: LearningScreen(repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Filter topics'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzzz-no-match');
    await tester.pumpAndSettle();
    expect(find.textContaining('No topics match'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('Quiz'), findsWidgets);
  });
}
