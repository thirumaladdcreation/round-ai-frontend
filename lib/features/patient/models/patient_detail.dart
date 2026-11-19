import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/clinical_format.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/patient/models/plan_structured.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/tasks/models/patient_task.dart';

/// One line the backend computed from the chart, such as a trend, a conflict
/// or a change. It may arrive as plain text or as an object, so both are read.
class InsightItem extends Equatable {
  const InsightItem({required this.text, this.label = ''});

  factory InsightItem.fromJson(Object? json) {
    if (json is! Map) {
      return InsightItem(text: humanizeMissingToken(Json.string(json)));
    }
    final Map<String, dynamic> map = Json.map(json);
    final String label = Json.firstString(map, const <String>[
      'label',
      'name',
      'title',
      'metric',
    ]);
    String text = Json.firstString(map, const <String>[
      'text',
      'detail',
      'description',
      'summary',
      'message',
    ]);
    if (text.isEmpty) {
      text = formatInsightMap(map);
    }
    // Wire keys like clinician_plan should never appear as the label alone.
    final String displayLabel =
        label.contains('_') && text.isNotEmpty ? '' : label;
    return InsightItem(
      label: displayLabel,
      text: text.isEmpty ? humanizeMissingToken(label) : text,
    );
  }

  final String label;
  final String text;

  static List<InsightItem> list(Object? value) {
    if (value is! List) return const <InsightItem>[];
    return value
        .map(InsightItem.fromJson)
        .where((InsightItem i) => i.text.isNotEmpty || i.label.isNotEmpty)
        .toList();
  }

  @override
  List<Object> get props => <Object>[label, text];
}

/// `GET /patients/:id`.
class PatientDetail extends Equatable {
  const PatientDetail({
    required this.patient,
    required this.revision,
    this.planToday = const <String>[],
    this.planStructured,
    this.problems = const <Problem>[],
    this.missingInformation = const <String>[],
    this.trends = const <InsightItem>[],
    this.conflicts = const <InsightItem>[],
    this.tasks = const <PatientTask>[],
    this.demoSummary,
  });

  factory PatientDetail.fromJson(Map<String, dynamic> json) {
    final PlanStructured? structured = json['plan_structured'] == null
        ? null
        : PlanStructured.fromJson(json['plan_structured']);
    return PatientDetail(
      patient: PatientSummary.fromJson(json),
      revision: Json.integer(json['revision']),
      planToday: _lines(json['plan_today']),
      planStructured: structured,
      problems: Json.maps(json['problems']).map(Problem.fromJson).toList(),
      missingInformation: InsightItem.list(
        json['missing_information'],
      ).map((InsightItem i) {
        final String raw = i.label.isEmpty ? i.text : i.label;
        return humanizeMissingToken(raw);
      }).toList(),
      trends: InsightItem.list(json['trends']),
      conflicts: InsightItem.list(json['conflicts']),
      tasks: Json.maps(json['tasks']).map(PatientTask.fromJson).toList(),
    );
  }

  /// `plan_today` may be `{text, plan_date}`, a string, or a list of lines.
  static List<String> _lines(Object? value) {
    if (value is List) {
      return value
          .map((Object? e) => Json.string(e).trim())
          .where((String s) => s.isNotEmpty)
          .toList();
    }
    if (value is Map) {
      return _lines(value['text']);
    }
    final String text = Json.string(value).trim();
    if (text.isEmpty) return const <String>[];
    return text
        .split('\n')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
  }

  final PatientSummary patient;

  /// Chart revision. It goes up whenever confirmed facts or the plan change.
  final int revision;
  final List<String> planToday;
  final PlanStructured? planStructured;
  final List<Problem> problems;
  final List<String> missingInformation;
  final List<InsightItem> trends;
  final List<InsightItem> conflicts;
  final List<PatientTask> tasks;

  /// Only set by the demo repository, which has canned summary text.
  final String? demoSummary;

  bool get hasPlan => planToday.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[
    patient,
    revision,
    planToday,
    planStructured,
    problems,
    missingInformation,
    trends,
    conflicts,
    tasks,
    demoSummary,
  ];
}

/// `GET /patients/:id/changes`. It is computed from the chart, not by a model.
class PatientChanges extends Equatable {
  const PatientChanges({required this.hasBaseline, required this.items});

  factory PatientChanges.fromJson(Map<String, dynamic> json) {
    final bool noBaseline =
        Json.string(json['status']).toLowerCase() == 'no_baseline';
    return PatientChanges(
      hasBaseline: !noBaseline,
      items: InsightItem.list(json['changes'] ?? json['items']),
    );
  }

  final bool hasBaseline;
  final List<InsightItem> items;

  @override
  List<Object> get props => <Object>[hasBaseline, items];
}
