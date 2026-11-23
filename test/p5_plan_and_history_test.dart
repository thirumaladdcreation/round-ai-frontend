import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/features/notes/repository/notes_repository.dart';
import 'package:round_ai/features/patient/models/plan_structured.dart';

void main() {
  test('P5: PlanItem carries source/status/manually_edited', () {
    final PlanItem item = PlanItem.fromJson(<String, dynamic>{
      'label': 'AKI',
      'assessment': 'Cr rising',
      'plan': 'IVF',
      'source': 'dictation_proposal',
      'status': 'proposed',
      'manually_edited': false,
      'code': 'N17.9',
    });
    expect(item.source, 'dictation_proposal');
    expect(item.status, 'proposed');
    expect(item.manuallyEdited, isFalse);
    expect(item.code, 'N17.9');
    expect(item.toJson()['manually_edited'], isFalse);
  });

  test('P5: PlanStructured.fromJson reads versioned blocks', () {
    final PlanStructured plan = PlanStructured.fromJson(<String, dynamic>{
      'version': 1,
      'include_icd': true,
      'items': <Map<String, Object>>[
        <String, Object>{
          'label': 'CAP',
          'assessment': 'fever',
          'plan': 'abx',
          'code': 'J18.9',
          'source': 'clinician',
          'status': 'edited',
          'manually_edited': true,
        },
      ],
    });
    expect(plan.includeIcd, isTrue);
    expect(plan.items, hasLength(1));
    expect(plan.items.first.label, 'CAP');
    expect(plan.items.first.manuallyEdited, isTrue);
  });

  test('P5: NoteVersion model fields', () {
    const NoteVersion v = NoteVersion(
      version: 3,
      createdAt: '2026-11-24T10:00:00Z',
      editedBy: 'u1',
    );
    expect(v.version, 3);
    expect(v.editedBy, 'u1');
  });
}
