import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/sync/patient_status_store.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';

void main() {
  test('PatientStatusStore applies mutation patient_status snapshots', () {
    final PatientStatusStore store = PatientStatusStore();
    store.applyFromResponse(<String, Object>{
      'context_revision': 3,
      'patient_status': <String, Object>{
        'patient_id': 'p-rosa',
        'summary_state': 'Not generated',
        'unreviewed_facts': 0,
        'open_tasks': 2,
        'revision': 3,
      },
    });
    final PatientStatusSnapshot? snap = store.get('p-rosa');
    expect(snap, isNotNull);
    expect(snap!.unreviewedFacts, 0);
    expect(snap.openTasks, 2);
    expect(snap.summaryState, 'Not generated');
    expect(snap.revision, 3);
  });

  test('overlay updates census row counts without refetch', () {
    final PatientStatusStore store = PatientStatusStore();
    store.applyFromResponse(<String, Object>{
      'patient_status': <String, Object>{
        'patient_id': 'p-rosa',
        'summary_state': 'Draft ready',
        'unreviewed_facts': 1,
        'open_tasks': 0,
        'revision': 4,
      },
    });
    const PatientSummary base = PatientSummary(
      id: 'p-rosa',
      teamId: 't1',
      displayName: 'Rosa',
      room: '509A',
      ageBand: '60-69',
      sex: 'F',
      summaryState: SummaryState.notGenerated,
      unreviewedFacts: 5,
      openTasks: 3,
    );
    final PatientSummary merged = store.overlay(base);
    expect(merged.unreviewedFacts, 1);
    expect(merged.openTasks, 0);
    expect(merged.summaryState, SummaryState.draftReady);
  });
}
