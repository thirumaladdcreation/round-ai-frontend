import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/features/learning/repository/demo_teaching_repository.dart';
import 'package:round_ai/features/learning/screens/learning_screen.dart';
import 'package:round_ai/features/patient/data/patient_workspace.dart';
import 'package:round_ai/features/rounds/repository/demo_round_repository.dart';
import 'package:round_ai/features/rounds/screens/rounds_screen.dart';
import 'package:round_ai/features/tasks/screens/tasks_screen.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  DemoTaskBoard.reset();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('tasks shows open, due now and completed counts', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(const MaterialApp(home: TasksScreen()));
    expect(find.text('COMMAND CENTER'), findsOneWidget);
    expect(find.text('Clarify urine output with bedside RN'), findsOneWidget);

    await tester.tap(find.text('Clarify urine output with bedside RN'));
    await tester.pump();
    expect(DemoTaskBoard.isDone('t-509a-urine'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rounds walks patients from the day brief', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: RoundsScreen(repository: DemoRoundRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rosa Martinez'), findsOneWidget);
    expect(find.text('PRESENTATION BUILDER'), findsOneWidget);
    expect(find.text('What changed'), findsWidgets);
    expect(find.textContaining('No approved reminders'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Mark rounded'), 200);
    await tester.ensureVisible(find.text('Mark rounded'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark rounded'));
    await tester.pumpAndSettle();
    expect(find.text('Daniel Brooks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('learning shows today’s topics without patient names', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: LearningScreen(repository: DemoTeachingRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Today’s topics'), findsOneWidget);
    expect(find.text('Rosa Martinez'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
