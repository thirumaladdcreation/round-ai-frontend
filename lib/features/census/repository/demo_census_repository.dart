import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/census/data/demo_patients.dart';
import 'package:round_ai/features/census/models/census_intake.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';
import 'package:round_ai/features/patient/data/patient_workspace.dart';

/// Fictional list for `USE_DEMO=true`. Nothing leaves the device.
class DemoCensusRepository implements CensusRepository {
  final List<PatientSummary> _added = <PatientSummary>[];
  final Map<String, int> _sort = <String, int>{};

  /// Patients added during this run. The demo patient screen reads them.
  List<PatientSummary> get added => List<PatientSummary>.unmodifiable(_added);

  static Failure get _off => ApiFailure(
    const ApiError(code: 'ai_disabled', message: 'Demo build', status: 503),
  );

  @override
  Future<Result<List<PatientSummary>>> loadPatients() async {
    final List<PatientSummary> list = <PatientSummary>[
      for (int i = 0; i < demoPatients.length; i++)
        PatientSummary(
          id: demoPatients[i].id,
          teamId: 'internal-medicine',
          displayName: demoPatients[i].name,
          room: demoPatients[i].room,
          ageBand: demoPatients[i].ageSex.substring(
            0,
            demoPatients[i].ageSex.length - 1,
          ),
          sex: demoPatients[i].ageSex.substring(
            demoPatients[i].ageSex.length - 1,
          ),
          summaryState: SummaryState.notGenerated,
          unreviewedFacts: 0,
          openTasks: allDemoTasks
              .where(
                (ChartTask t) =>
                    t.patientId == demoPatients[i].id &&
                    !DemoTaskBoard.isDone(t.id),
              )
              .length,
          sortOrder: _sort[demoPatients[i].id] ?? i,
        ),
      for (int i = 0; i < _added.length; i++)
        PatientSummary(
          id: _added[i].id,
          teamId: _added[i].teamId,
          displayName: _added[i].displayName,
          room: _added[i].room,
          ageBand: _added[i].ageBand,
          sex: _added[i].sex,
          summaryState: _added[i].summaryState,
          unreviewedFacts: _added[i].unreviewedFacts,
          openTasks: _added[i].openTasks,
          sortOrder: _sort[_added[i].id] ?? (demoPatients.length + i),
        ),
    ]..sort(PatientSummary.compareCensus);
    return Ok<List<PatientSummary>>(list);
  }

  @override
  Future<Result<PatientSummary>> addPatient(NewPatient patient) async {
    final PatientSummary added = PatientSummary(
      id: 'demo-${_added.length + 1}',
      teamId: patient.teamId,
      displayName: patient.displayName,
      room: patient.room,
      ageBand: patient.ageBand,
      sex: patient.sex,
      summaryState: SummaryState.notGenerated,
      unreviewedFacts: 0,
      openTasks: 0,
      sortOrder: demoPatients.length + _added.length,
    );
    _added.add(added);
    return Ok<PatientSummary>(added);
  }

  @override
  Future<Result<CensusIntakeProposal>> intakeCensus({
    required TempMedia media,
    required String idempotencyKey,
    String? teamId,
    CancelToken? cancelToken,
  }) async {
    await media.delete();
    return Err<CensusIntakeProposal>(_off);
  }

  @override
  Future<Result<CensusConfirmResult>> confirmCensus(
    String intakeId, {
    required List<ProposedCensusPatient> items,
  }) async => Err<CensusConfirmResult>(_off);

  @override
  Future<Result<CensusExport>> exportCensus({String? teamId}) async {
    final Result<List<PatientSummary>> loaded = await loadPatients();
    switch (loaded) {
      case Err<List<PatientSummary>>(:final failure):
        return Err<CensusExport>(failure);
      case Ok<List<PatientSummary>>(:final value):
        final String text = value
            .asMap()
            .entries
            .map((MapEntry<int, PatientSummary> e) {
              final PatientSummary p = e.value;
              final List<String> bits = <String>[
                p.room.isEmpty ? '—' : p.room,
                p.displayName,
                if (p.ageBand.isNotEmpty) p.ageBand,
                if (p.sex.isNotEmpty) p.sex,
              ];
              return '${(e.key + 1).toString().padLeft(2)}. ${bits.join(' · ')}';
            })
            .join('\n');
        return Ok<CensusExport>(
          CensusExport(
            text: text,
            note:
                'Demo printable census. Ordering is clinician sort_order, then room.',
            orderedBy: 'sort_order_then_room',
            patientCount: value.length,
          ),
        );
    }
  }

  @override
  Future<Result<void>> setSortOrder(String patientId, int sortOrder) async {
    _sort[patientId] = sortOrder;
    return const Ok<void>(null);
  }
}
