import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/features/patient/models/plan_structured.dart';

void main() {
  test('tryParseNoteText keeps Assessment under each problem', () {
    const String raw = '''
community-acquired pneumonia
Assessment: Hospital day 3; cultures pending.
Plan: Continue ceftriaxone and azithromycin.
acute kidney injury
Assessment: Creatinine increased from 0.9 to 2.1 mg/dL.
Plan: Hold nephrotoxins; recheck creatinine.
''';
    final PlanStructured? plan = PlanStructured.tryParseNoteText(raw);
    expect(plan, isNotNull);
    expect(plan!.items, hasLength(2));
    expect(plan.items[0].label, 'community-acquired pneumonia');
    expect(plan.items[0].assessment, contains('Hospital day 3'));
    expect(plan.items[0].plan, contains('ceftriaxone'));
    expect(plan.items[1].label, 'acute kidney injury');
    expect(plan.items[1].plan, contains('nephrotoxins'));
  });

  test('tryParseNoteText returns null for flat prose without markers', () {
    expect(
      PlanStructured.tryParseNoteText(
        'Continue current antibiotics and reassess oxygen overnight.',
      ),
      isNull,
    );
  });

  test('toDisplayLines round-trips through tryParseNoteText', () {
    const PlanStructured original = PlanStructured(
      items: <PlanItem>[
        PlanItem(
          label: 'Elevated Pulse',
          assessment: 'Pulse 112 with rising oxygen need.',
          plan: 'Correlate with volume and gas exchange.',
        ),
      ],
    );
    final PlanStructured? parsed = PlanStructured.tryParseNoteText(
      original.toDisplayLines().join('\n'),
    );
    expect(parsed, isNotNull);
    expect(parsed!.items.single.label, 'Elevated Pulse');
    expect(parsed.items.single.plan, contains('volume'));
  });
}
