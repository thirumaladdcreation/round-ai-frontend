import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/features/patient/models/fact.dart';
import 'package:round_ai/features/patient/utils/fact_display.dart';

void main() {
  test('keeps SpO2 room-air context on the value line', () {
    const Fact fact = Fact(
      id: '1',
      name: 'SpO2',
      value: '88',
      unit: '%',
      status: FactStatus.pending,
      passage: 'SpO2 88% on room air overnight',
    );
    expect(factValueLine(fact), '88 % · on room air');
    expect(oxygenContextHint(fact), 'on room air');
  });

  test('detects supplemental liters from passage', () {
    const Fact fact = Fact(
      id: '2',
      name: 'SpO2',
      value: '94',
      unit: '%',
      status: FactStatus.pending,
      passage: 'now SpO2 94% on 2 L NC',
    );
    expect(oxygenContextHint(fact), contains('2 L'));
    expect(factValueLine(fact), contains('supplemental'));
  });
}
