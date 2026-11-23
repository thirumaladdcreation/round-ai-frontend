import 'package:flutter/foundation.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';

/// Per-patient census/home counts from mutation `patient_status` snapshots.
class PatientStatusSnapshot {
  const PatientStatusSnapshot({
    required this.patientId,
    required this.summaryState,
    required this.unreviewedFacts,
    required this.openTasks,
    required this.revision,
  });

  factory PatientStatusSnapshot.fromJson(Map<String, dynamic> json) {
    return PatientStatusSnapshot(
      patientId: '${json['patient_id'] ?? ''}',
      summaryState: '${json['summary_state'] ?? ''}',
      unreviewedFacts: _int(json['unreviewed_facts']),
      openTasks: _int(json['open_tasks']),
      revision: _int(json['revision']),
    );
  }

  final String patientId;
  final String summaryState;
  final int unreviewedFacts;
  final int openTasks;
  final int revision;

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

/// Single in-memory source of truth for patient list status chips/counts.
///
/// Mutations apply [PatientStatusSnapshot] from the API; [CensusSync] still
/// triggers full refreshes as a fallback.
class PatientStatusStore extends ChangeNotifier {
  final Map<String, PatientStatusSnapshot> _byId =
      <String, PatientStatusSnapshot>{};

  PatientStatusSnapshot? get(String patientId) => _byId[patientId];

  /// Applies a `patient_status` object from a mutation response body.
  void applyFromResponse(Object? body) {
    if (body is! Map) return;
    final Object? raw = body['patient_status'];
    if (raw is! Map) return;
    final PatientStatusSnapshot snap = PatientStatusSnapshot.fromJson(
      Map<String, dynamic>.from(raw),
    );
    if (snap.patientId.isEmpty) return;
    _byId[snap.patientId] = snap;
    notifyListeners();
  }

  /// Overlays the latest mutation snapshot onto a census row (no refetch).
  PatientSummary overlay(PatientSummary patient) {
    final PatientStatusSnapshot? snap = _byId[patient.id];
    if (snap == null) return patient;
    return patient.copyWith(
      summaryState: snap.summaryState.isEmpty
          ? null
          : SummaryState.parse(snap.summaryState),
      unreviewedFacts: snap.unreviewedFacts,
      openTasks: snap.openTasks,
    );
  }

  List<PatientSummary> overlayAll(List<PatientSummary> patients) {
    if (_byId.isEmpty) return patients;
    return patients.map(overlay).toList(growable: false);
  }

  void clear() {
    if (_byId.isEmpty) return;
    _byId.clear();
    notifyListeners();
  }
}
