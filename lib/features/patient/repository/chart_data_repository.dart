import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/patient/models/chart_source.dart';
import 'package:round_ai/features/patient/models/fact.dart';

/// What the clinician types for a manual fact.
class NewFact {
  const NewFact({
    required this.name,
    required this.value,
    this.unit,
    this.eventTime,
  });

  final String name;
  final String value;
  final String? unit;
  final DateTime? eventTime;

  Map<String, Object> toJson() => <String, Object>{
    // Backend field is `label` (see POST /patients/:id/facts).
    'label': name,
    'value': value,
    if (unit != null && unit!.isNotEmpty) 'unit': unit!,
    if (eventTime != null) 'event_time': eventTime!.toUtc().toIso8601String(),
  };
}

/// Chart data entry. AI only uses facts a clinician has confirmed, so this
/// is where the flow starts: source text, extraction, review, confirm.
abstract class ChartDataRepository {
  Future<Result<ChartSource>> addSource(
    String patientId, {
    required ChartSourceKind kind,
    required DateTime time,
    required String text,
  });

  /// Saved sources for this patient (titles/kinds only — no PHI text).
  Future<Result<List<ChartSource>>> listSources(String patientId);

  /// Reads facts out of a saved source. They arrive as pending.
  Future<Result<void>> extract(String patientId, String sourceId);

  Future<Result<List<Fact>>> pendingFacts(String patientId);

  /// Confirms or rejects facts via `POST .../facts/review`.
  Future<Result<void>> decide(
    String patientId,
    List<String> factIds, {
    required bool confirm,
  });

  Future<Result<void>> addFact(String patientId, NewFact fact);
}
