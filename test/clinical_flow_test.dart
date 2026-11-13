import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/features/patient/screens/evidence_screen.dart';
import 'package:round_ai/features/patient/screens/presentation_screen.dart';
import 'package:round_ai/features/rounds/repository/demo_round_repository.dart';

void main() {
  testWidgets('presentation shows the oral draft and missing facts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PresentationScreen(
          patientId: 'p-412b',
          roundRepository: DemoRoundRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Oral draft'), findsOneWidget);
    expect(find.textContaining('Oxygen support'), findsWidgets);
    expect(find.textContaining('target 150–220'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('evidence does not invent a retrieved study', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EvidenceScreen(patientId: 'p-412b')),
    );
    expect(
      find.textContaining('No relevant recent studies found'),
      findsOneWidget,
    );
    expect(find.textContaining('PMID'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
