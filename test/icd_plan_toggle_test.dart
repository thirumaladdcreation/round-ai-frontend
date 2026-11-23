import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/features/patient/models/plan_structured.dart';

void main() {
  const PlanStructured plan = PlanStructured(
    includeIcd: false,
    items: <PlanItem>[
      PlanItem(
        label: 'community-acquired pneumonia',
        assessment: 'Hospital day 3; cultures pending.',
        plan: 'Continue ceftriaxone and azithromycin.',
        code: 'J18.9',
      ),
      PlanItem(
        label: 'acute kidney injury',
        assessment: 'Creatinine 0.9 → 2.1 with oliguria.',
        plan: 'Hold nephrotoxins; recheck creatinine.',
        code: 'N17.9',
      ),
      PlanItem(
        label: 'Elevated Pulse',
        assessment: 'Pulse 112 with rising oxygen need.',
        plan: 'Correlate with volume and gas exchange.',
      ),
    ],
  );

  test('toggle off omits codes but keeps clinical wording', () {
    final List<String> lines = plan.toDisplayLines(withIcd: false);
    final String text = lines.join('\n');
    expect(text, contains('community-acquired pneumonia'));
    expect(text, contains('Hospital day 3; cultures pending.'));
    expect(text, contains('Continue ceftriaxone and azithromycin.'));
    expect(text, isNot(contains('J18.9')));
    expect(text, isNot(contains('N17.9')));
    expect(text, contains('Elevated Pulse'));
  });

  test('toggle on shows accepted codes beside diagnoses only', () {
    final List<String> lines = plan.toDisplayLines(withIcd: true);
    expect(lines.first, 'community-acquired pneumonia (J18.9)');
    expect(lines, contains('acute kidney injury (N17.9)'));
    expect(lines, contains('Elevated Pulse'));
    expect(
      lines.any((String l) => l.startsWith('Elevated Pulse (')),
      isFalse,
      reason: 'No invented code for Elevated Pulse',
    );
    // Assessment/plan wording unchanged.
    expect(lines.join('\n'), contains('Hospital day 3; cultures pending.'));
    expect(lines.join('\n'), contains('Hold nephrotoxins; recheck creatinine.'));
  });

  test('codeForLabel fills missing item codes when toggle on', () {
    final PlanStructured withoutStored = PlanStructured(
      includeIcd: true,
      items: <PlanItem>[
        const PlanItem(
          label: 'community-acquired pneumonia',
          assessment: 'A',
          plan: 'P',
        ),
      ],
    );
    final List<String> lines = withoutStored.toDisplayLines(
      withIcd: true,
      codeForLabel: (PlanItem item) =>
          item.label == 'community-acquired pneumonia' ? 'J18.9' : null,
    );
    expect(lines.first, 'community-acquired pneumonia (J18.9)');
  });
}
