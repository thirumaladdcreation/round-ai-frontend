import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/features/patient/models/fact.dart';
import 'package:round_ai/features/patient/utils/fact_display.dart';

void main() {
  test('factValueLine prefers qualifier over inferred O2 hint', () {
    const Fact fact = Fact(
      id: '1',
      name: 'SpO2',
      value: '88',
      unit: '%',
      status: FactStatus.pending,
      qualifier: 'on room air',
      passage: 'SpO2 88% on room air',
    );
    expect(factValueLine(fact), '88 % · on room air');
  });

  test('Fact.fromJson reads qualifier and warnings', () {
    final Fact fact = Fact.fromJson(<String, dynamic>{
      'id': 'f1',
      'label': 'Creatinine',
      'value': '2.1',
      'unit': 'mg/dL',
      'reviewer_status': 'pending',
      'qualifier': null,
      'warnings': <Object>[
        <String, Object>{
          'code': 'implausible_date',
          'message': 'Event time 2020-01-15 is far from today.',
        },
      ],
    });
    expect(fact.name, 'Creatinine');
    expect(fact.warnings, hasLength(1));
    expect(fact.warnings.first.code, 'implausible_date');
  });

  test('PlanProposal.fromJson maps dictation fields', () {
    final PlanProposal p = PlanProposal.fromJson(<String, dynamic>{
      'title': 'Acute kidney injury',
      'plan_text': 'continue IVF',
      'problem_id': 'p1',
      'is_new_problem': false,
    });
    expect(p.title, 'Acute kidney injury');
    expect(p.planText, 'continue IVF');
    expect(p.problemId, 'p1');
  });
}
