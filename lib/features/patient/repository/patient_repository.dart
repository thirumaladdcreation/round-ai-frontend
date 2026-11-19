import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/models/plan_structured.dart';

abstract class PatientRepository {
  /// `GET /patients/:id`.
  Future<Result<PatientDetail>> loadDetail(String patientId);

  /// `GET /patients/:id/changes`. Computed from the chart, not by AI.
  Future<Result<PatientChanges>> loadChanges(String patientId);

  /// `PUT /patients/:id/plan`. One entry per line of today's plan (legacy).
  Future<Result<void>> savePlan(String patientId, List<String> lines);

  /// `PUT /patients/:id/plan` with problem-wise items + ICD toggle.
  Future<Result<void>> saveStructuredPlan(
    String patientId,
    PlanStructured plan,
  );
}
