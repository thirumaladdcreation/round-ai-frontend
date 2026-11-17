import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';
import 'package:round_ai/features/rounds/models/round_brief.dart';
import 'package:round_ai/features/rounds/repository/round_repository.dart';
import 'package:round_ai/features/today/models/home_greeting.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/repository/home_repository.dart';

/// Builds the home snapshot from the team's real census.
///
/// Every number here is a count of chart data. Nothing is ranked by AI, and
/// the "needs attention" list only names things the chart data shows: facts
/// waiting for review, outdated summaries and open tasks.
class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(
    this._census,
    this._storage, {
    RoundRepository? roundRepository,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CensusRepository _census;
  final AppStorage _storage;
  final DateTime Function() _clock;

  @override
  Future<Result<HomeSnapshot>> load() async {
    final Result<List<PatientSummary>> result = await _census.loadPatients();
    switch (result) {
      case Err<List<PatientSummary>>(:final failure):
        return Err<HomeSnapshot>(failure);
      case Ok<List<PatientSummary>>(:final value):
        // Census list is the source of truth for pending facts and summary
        // state so Today stays consistent with Census after confirm/generate.
        final RoundBriefCounts counts = _countsFromCensus(value);
        return Ok<HomeSnapshot>(_snapshot(value, counts));
    }
  }

  RoundBriefCounts _countsFromCensus(List<PatientSummary> patients) {
    return RoundBriefCounts(
      patients: patients.length,
      unreviewedFacts: patients.fold<int>(
        0,
        (int sum, PatientSummary p) => sum + p.unreviewedFacts,
      ),
      outdatedSummaries: patients
          .where((PatientSummary p) => p.summaryState == SummaryState.outdated)
          .length,
    );
  }

  HomeSnapshot _snapshot(
    List<PatientSummary> patients,
    RoundBriefCounts counts,
  ) {
    final DateTime now = _clock();
    return HomeSnapshot(
      clinicianName: _storage.clinicianName,
      greeting: HomeGreeting.forTime(now),
      dateLabel: HomeGreeting.formatDate(now),
      patientCount: patients.length,
      pendingTaskCount: patients.fold<int>(
        0,
        (int sum, PatientSummary p) => sum + p.openTasks,
      ),
      draftsAwaitingReview: patients
          .where(
            (PatientSummary p) => p.summaryState == SummaryState.draftReady,
          )
          .length,
      roundsStatus: counts.isQuiet
          ? 'No chart facts are waiting for review'
          : counts.headline,
      // The backend does not report a chart stamp.
      latestChartStamp: '',
      patients: patients.map(_preview).toList(),
      attention: _attention(patients),
      isSynthetic: false,
      hasPartialChart: patients.any((PatientSummary p) => p.ageBand.isEmpty),
      briefCounts: counts,
    );
  }

  HomePatientPreview _preview(PatientSummary p) {
    final List<String> changeBits = <String>[
      if (p.unreviewedFacts > 0)
        '${p.unreviewedFacts} pending ${p.unreviewedFacts == 1 ? 'fact' : 'facts'}',
      if (p.openTasks > 0)
        '${p.openTasks} open ${p.openTasks == 1 ? 'task' : 'tasks'}',
    ];
    return HomePatientPreview(
      id: p.id,
      name: p.displayName,
      room: p.room,
      ageLabel: p.ageBand.isEmpty ? null : p.ageBand,
      genderLabel: switch (p.sex.toUpperCase()) {
        'F' => 'Female',
        'M' => 'Male',
        '' => null,
        _ => p.sex,
      },
      // Census list does not carry a one-liner; meta + status stay honest.
      reason: p.metaLine.isEmpty ? p.displayName : p.metaLine,
      latestUpdate: changeBits.isEmpty
          ? 'Ready for rounds'
          : changeBits.join(' · '),
      pendingTasks: p.openTasks,
      noteStatus: p.summaryState.label,
      pendingFacts: p.unreviewedFacts,
    );
  }

  /// Plain facts about the data. Not a risk ranking.
  List<HomeAttentionItem> _attention(List<PatientSummary> patients) {
    final List<HomeAttentionItem> items = <HomeAttentionItem>[];
    for (final PatientSummary p in patients) {
      if (p.unreviewedFacts > 0) {
        items.add(
          HomeAttentionItem(
            id: 'facts-${p.id}',
            title: 'Chart facts to review',
            detail:
                '${p.displayName} · ${p.unreviewedFacts} waiting for review',
            route: AppRoutes.patientFactsPath(p.id),
          ),
        );
      }
      if (p.summaryState == SummaryState.outdated) {
        items.add(
          HomeAttentionItem(
            id: 'outdated-${p.id}',
            title: 'Summary is outdated',
            detail: '${p.displayName} · the chart changed after it was made',
            route: AppRoutes.patientPath(p.id),
          ),
        );
      }
    }
    return items.take(4).toList();
  }
}
