import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/features/census/models/census_intake.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';

/// What the clinician types to add a patient. Dev data is fictional.
class NewPatient {
  const NewPatient({
    required this.teamId,
    required this.displayName,
    required this.room,
    required this.ageBand,
    required this.sex,
  });

  final String teamId;
  final String displayName;
  final String room;
  final String ageBand;
  final String sex;

  Map<String, String> toJson() => <String, String>{
    'team_id': teamId,
    'display_name': displayName,
    'room': room,
    'age_band': ageBand,
    'sex': sex,
  };
}

abstract class CensusRepository {
  /// Patients of the selected team. Ordered by sort_order, then room.
  Future<Result<List<PatientSummary>>> loadPatients();

  Future<Result<PatientSummary>> addPatient(NewPatient patient);

  /// Photo or voice → proposed patients only (nothing created yet).
  Future<Result<CensusIntakeProposal>> intakeCensus({
    required TempMedia media,
    required String idempotencyKey,
    String? teamId,
    CancelToken? cancelToken,
  });

  /// Confirm / skip proposed rows. Creates patients + pending reason facts.
  Future<Result<CensusConfirmResult>> confirmCensus(
    String intakeId, {
    required List<ProposedCensusPatient> items,
  });

  /// Deterministic printable list. Never AI-ranked.
  Future<Result<CensusExport>> exportCensus({String? teamId});

  /// Persist manual census order (`PATCH /patients/:id` sort_order).
  Future<Result<void>> setSortOrder(String patientId, int sortOrder);
}
