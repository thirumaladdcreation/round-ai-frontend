import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/config/shell_tabs.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/census/screens/census_screen.dart';
import 'package:round_ai/shared/widgets/app_bottom_nav_bar.dart';

void main() {
  tearDown(() => AppFeatures.forceAll = null);

  test('P3 bottom nav is Patients · Tasks · Learn · Chat', () {
    AppFeatures.forceAll = null;
    expect(ShellTabs.visible, <ShellTab>[
      ShellTab.census,
      ShellTab.tasks,
      ShellTab.learn,
      ShellTab.chat,
    ]);
    expect(ShellTabs.visible.contains(ShellTab.today), isFalse);
    expect(ShellTabs.visible.contains(ShellTab.scribe), isFalse);
    expect(ShellTabs.visible.contains(ShellTab.rounds), isFalse);
  });

  testWidgets('bottom bar has no Home/Scribe/Rounds labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppBottomNavBar(currentIndex: 0, onItemSelected: (_) {}),
        ),
      ),
    );
    expect(find.text('Patients'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Learn'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Scribe'), findsNothing);
    expect(find.text('Rounds'), findsNothing);
  });

  testWidgets('census row shows one-liner, changes, and review badge', (
    WidgetTester tester,
  ) async {
    const PatientSummary patient = PatientSummary(
      id: 'p1',
      teamId: 't1',
      displayName: 'Rosa Martinez',
      room: '509A',
      ageBand: '60-69',
      sex: 'F',
      summaryState: SummaryState.draftReady,
      unreviewedFacts: 2,
      openTasks: 1,
      oneLiner: '60-69 F with acute kidney injury',
      keyChanges: <String>[
        'Creatinine increased from 0.9 to 2.1 mg/dL',
        'SpO2 decreased from 93% to 88%',
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatientCard(patient: patient, onTap: () {}),
        ),
      ),
    );
    expect(find.text('Rosa Martinez'), findsOneWidget);
    expect(find.textContaining('509A'), findsOneWidget);
    expect(find.textContaining('acute kidney injury'), findsOneWidget);
    expect(find.textContaining('Creatinine increased'), findsOneWidget);
    expect(find.text('2 facts to review'), findsOneWidget);
    expect(find.text('1 open task'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
  });

  test('post-login landing is Patients (census)', () {
    expect(AppRoutes.census, '/census');
  });
}
