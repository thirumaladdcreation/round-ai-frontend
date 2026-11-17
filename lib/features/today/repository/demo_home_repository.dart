import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/features/census/data/demo_patients.dart';
import 'package:round_ai/features/patient/data/patient_workspace.dart';
import 'package:round_ai/features/rounds/models/round_brief.dart';
import 'package:round_ai/features/rounds/repository/demo_round_repository.dart';
import 'package:round_ai/features/rounds/repository/round_repository.dart';
import 'package:round_ai/features/today/models/home_greeting.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/repository/home_repository.dart';

/// Home snapshot from the demo list, for `USE_DEMO=true`.
/// Patient order is the team list. It is not an urgency ranking.
class DemoHomeRepository implements HomeRepository {
  DemoHomeRepository(
    this._storage, {
    RoundRepository? roundRepository,
    DateTime Function()? clock,
  }) : _rounds = roundRepository ?? DemoRoundRepository(clock: clock),
       _clock = clock ?? DateTime.now;

  final AppStorage _storage;
  final RoundRepository _rounds;
  final DateTime Function() _clock;

  @override
  Future<Result<HomeSnapshot>> load() async {
    final DateTime now = _clock();
    final List<ChartTask> openTasks = allDemoTasks
        .where((ChartTask task) => !DemoTaskBoard.isDone(task.id))
        .toList();
    final List<HomePatientPreview> preview = demoPatients
        .map(
          (CensusPatient patient) => HomePatientPreview(
            id: patient.id,
            name: patient.name,
            room: patient.room,
            ageLabel: _ageLabel(patient.detail),
            genderLabel: _genderLabel(patient.summary),
            reason: patient.problem.isEmpty
                ? _reason(patient.detail)
                : patient.problem,
            latestUpdate: patient.keyFinding.isEmpty
                ? patient.updatedLabel
                : patient.keyFinding,
            pendingTasks: openTasks
                .where((ChartTask task) => task.patientId == patient.id)
                .length,
            noteStatus: patient.statusText,
            pendingFacts: 0,
          ),
        )
        .toList();

    RoundBriefCounts counts = const RoundBriefCounts();
    final Result<RoundBrief> brief = await _rounds.loadBrief();
    if (brief case Ok<RoundBrief>(value: final RoundBrief briefValue)) {
      counts = briefValue.counts;
    }

    return Ok<HomeSnapshot>(
      HomeSnapshot(
        clinicianName: _storage.clinicianName,
        greeting: HomeGreeting.forTime(now),
        dateLabel: HomeGreeting.formatDate(now),
        patientCount: demoPatients.length,
        pendingTaskCount: openTasks.length,
        draftsAwaitingReview: 0,
        roundsStatus: counts.isQuiet
            ? 'Preparation has not been started'
            : counts.headline,
        latestChartStamp: demoPatients.isEmpty
            ? 'No chart stamp on this list'
            : demoPatients.first.updatedLabel,
        patients: preview,
        attention: _attention(openTasks),
        isSynthetic: true,
        hasPartialChart: preview.any(
          (HomePatientPreview patient) =>
              patient.ageLabel == null || patient.genderLabel == null,
        ),
        briefCounts: counts,
      ),
    );
  }

  List<HomeAttentionItem> _attention(List<ChartTask> openTasks) {
    final List<HomeAttentionItem> items = <HomeAttentionItem>[];
    for (final ChartTask task in openTasks.take(2)) {
      items.add(
        HomeAttentionItem(
          id: task.id,
          title: task.title,
          detail: task.patientName,
          route: AppRoutes.patientTasksPath(task.patientId),
        ),
      );
    }
    for (final PatientWorkspace workspace in demoWorkspaces) {
      if (workspace.missing.isEmpty || items.length >= 4) continue;
      final CensusPatient? patient = patientById(workspace.patientId);
      if (patient == null) continue;
      items.add(
        HomeAttentionItem(
          id: 'doc-${patient.id}',
          title: 'Chart item not entered',
          detail: '${patient.name} · ${workspace.missing.first}',
          route: AppRoutes.notePath(patient.id),
        ),
      );
      break;
    }
    for (final PatientWorkspace workspace in demoWorkspaces) {
      if (items.length >= 4) break;
      if (!workspace.signOut.toLowerCase().contains('contingency')) continue;
      final CensusPatient? patient = patientById(workspace.patientId);
      if (patient == null) continue;
      items.add(
        HomeAttentionItem(
          id: 'signout-${patient.id}',
          title: 'Sign-out not finalized',
          detail: '${patient.name} · contingency instructions are not written',
          route: AppRoutes.signOutPath(patient.id),
        ),
      );
      break;
    }
    return items;
  }

  String? _genderLabel(String summary) {
    final String lower = summary.toLowerCase();
    if (RegExp(r'\bmale\b').hasMatch(lower)) return 'Male';
    if (RegExp(r'\bfemale\b').hasMatch(lower)) return 'Female';
    if (RegExp(r'\bwoman\b').hasMatch(lower)) return 'Woman';
    if (RegExp(r'\bman\b').hasMatch(lower)) return 'Man';
    return null;
  }

  String? _ageLabel(String detail) {
    final RegExpMatch? match = RegExp(
      r'(\d+)\s*yrs',
      caseSensitive: false,
    ).firstMatch(detail);
    if (match == null) return null;
    return '${match.group(1)} yrs';
  }

  String _reason(String detail) {
    final List<String> parts = detail.split('·');
    if (parts.length < 2) return detail;
    return parts.last.trim();
  }
}
