import 'package:round_ai/features/rounds/models/round_brief.dart';

class HomePatientPreview {
  const HomePatientPreview({
    required this.id,
    required this.name,
    required this.room,
    required this.reason,
    required this.latestUpdate,
    required this.pendingTasks,
    this.ageLabel,
    this.genderLabel,
  });

  final String id;
  final String name;
  final String room;
  final String? ageLabel;
  final String? genderLabel;
  final String reason;
  final String latestUpdate;
  final int pendingTasks;
}

class HomeAttentionItem {
  const HomeAttentionItem({
    required this.id,
    required this.title,
    required this.detail,
    required this.route,
    this.owner,
    this.dueLabel,
  });

  final String id;
  final String title;
  final String detail;
  final String route;
  final String? owner;
  final String? dueLabel;
}

/// Values for the home screen. Counts come from the team list, not a model.
class HomeSnapshot {
  const HomeSnapshot({
    required this.clinicianName,
    required this.greeting,
    required this.dateLabel,
    required this.patientCount,
    required this.pendingTaskCount,
    required this.draftsAwaitingReview,
    required this.roundsStatus,
    required this.latestChartStamp,
    required this.patients,
    required this.attention,
    required this.isSynthetic,
    required this.hasPartialChart,
    this.briefCounts = const RoundBriefCounts(),
  });

  final String clinicianName;
  final String greeting;
  final String dateLabel;
  final int patientCount;
  final int pendingTaskCount;
  final int draftsAwaitingReview;
  final String roundsStatus;
  final String latestChartStamp;
  final List<HomePatientPreview> patients;
  final List<HomeAttentionItem> attention;

  /// Demo lists are labeled. They are not signed notes or model output.
  final bool isSynthetic;

  /// True when a listed patient has no age on the chart.
  final bool hasPartialChart;

  /// Deterministic morning-brief counts from `GET /round/brief`.
  final RoundBriefCounts briefCounts;
}
