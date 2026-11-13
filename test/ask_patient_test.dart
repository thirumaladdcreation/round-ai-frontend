import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/features/census/data/demo_patients.dart';
import 'package:round_ai/features/patient/data/patient_workspace.dart';
import 'package:round_ai/features/patient/widgets/ask_patient_sheet.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';

AskAnswer _ask(String question) {
  final CensusPatient patient = demoPatients.first;
  return answerFor(question, patient, workspaceFor(patient.id));
}

void main() {
  test('chart questions answer from the chart', () {
    final AskAnswer answer = _ask('What changed today?');
    expect(answer.label, 'From chart');
    expect(answer.lines.join(' '), contains('Creatinine'));
  });

  test('evidence questions never invent a study', () {
    final AskAnswer answer = _ask('Find recent studies');
    expect(answer.state, AiState.noEvidence);
    expect(answer.lines.join(' '), contains('No relevant recent studies'));
    expect(answer.lines.join(' '), isNot(contains('PMID')));
  });

  test('a missing plan is not filled in', () {
    final AskAnswer answer = _ask('Draft today’s assessment using my plan');
    expect(answer.state, AiState.partial);
    expect(answer.lines.first, contains('not entered'));
  });

  test('an ambiguous question asks a focused question', () {
    final AskAnswer answer = _ask('hmm');
    expect(answer.label, 'Clarifying question');
  });

  test('an unknown patient is denied', () {
    final AskAnswer answer = answerFor('Summarize', demoPatients.first, null);
    expect(answer.state, AiState.accessDenied);
  });
}
