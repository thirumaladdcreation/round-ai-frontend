import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/census/data/demo_patients.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/census/repository/demo_census_repository.dart';
import 'package:round_ai/features/patient/data/patient_workspace.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/models/plan_structured.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';

/// Canned detail for `USE_DEMO=true`. Nothing leaves the device.
class DemoPatientRepository implements PatientRepository {
  DemoPatientRepository(this._census);

  final DemoCensusRepository _census;
  final Map<String, List<String>> _plans = <String, List<String>>{};

  @override
  Future<Result<PatientDetail>> loadDetail(String patientId) async {
    final CensusPatient? demo = patientById(patientId);
    if (demo != null) {
      final PatientWorkspace? workspace = workspaceFor(patientId);
      return Ok<PatientDetail>(
        PatientDetail(
          patient: PatientSummary(
            id: demo.id,
            teamId: 'internal-medicine',
            displayName: demo.name,
            room: demo.room,
            ageBand: demo.ageSex.substring(0, demo.ageSex.length - 1),
            sex: demo.ageSex.substring(demo.ageSex.length - 1),
            summaryState: SummaryState.notGenerated,
            unreviewedFacts: 0,
            openTasks: 0,
          ),
          revision: 1,
          planToday: _plans[patientId] ?? const <String>[],
          missingInformation: workspace?.missing ?? const <String>[],
          demoSummary: demo.summary,
        ),
      );
    }
    for (final PatientSummary added in _census.added) {
      if (added.id == patientId) {
        return Ok<PatientDetail>(
          PatientDetail(
            patient: added,
            revision: 1,
            planToday: _plans[patientId] ?? const <String>[],
          ),
        );
      }
    }
    return Err<PatientDetail>(
      ApiFailure(const ApiError(code: 'access_denied', message: '')),
    );
  }

  @override
  Future<Result<PatientChanges>> loadChanges(String patientId) async {
    final PatientWorkspace? workspace = workspaceFor(patientId);
    if (workspace == null) {
      return const Ok<PatientChanges>(
        PatientChanges(hasBaseline: false, items: <InsightItem>[]),
      );
    }
    return Ok<PatientChanges>(
      PatientChanges(
        hasBaseline: true,
        items: <InsightItem>[
          for (final String line in workspace.changes) InsightItem(text: line),
        ],
      ),
    );
  }

  @override
  Future<Result<void>> savePlan(String patientId, List<String> lines) async {
    _plans[patientId] = lines;
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> saveStructuredPlan(
    String patientId,
    PlanStructured plan,
  ) async {
    _plans[patientId] = plan.toDisplayLines(withIcd: plan.includeIcd);
    return const Ok<void>(null);
  }
}
