import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/rounds/models/round_reminder.dart';

/// Deterministic day counts from `GET /round/brief`. No urgency ranking.
class RoundBriefCounts extends Equatable {
  const RoundBriefCounts({
    this.patients = 0,
    this.unreviewedFacts = 0,
    this.outdatedSummaries = 0,
    this.overdueTasks = 0,
  });

  factory RoundBriefCounts.fromJson(
    Map<String, dynamic> json, {
    int overdueTasks = 0,
  }) {
    return RoundBriefCounts(
      patients: Json.integer(json['patients']),
      unreviewedFacts: Json.integer(json['unreviewed_facts']),
      outdatedSummaries: Json.integer(json['outdated_summaries']),
      overdueTasks: overdueTasks,
    );
  }

  final int patients;
  final int unreviewedFacts;
  final int outdatedSummaries;

  /// Derived from per-patient task flags when the brief omits a count.
  final int overdueTasks;

  bool get isQuiet =>
      unreviewedFacts == 0 && outdatedSummaries == 0 && overdueTasks == 0;

  /// Plain count lines for the morning brief. No urgency wording.
  List<String> get lines {
    final List<String> out = <String>[];
    if (unreviewedFacts > 0) {
      out.add(
        unreviewedFacts == 1
            ? '1 chart fact is waiting for review'
            : '$unreviewedFacts chart facts are waiting for review',
      );
    }
    if (outdatedSummaries > 0) {
      out.add(
        outdatedSummaries == 1
            ? '1 summary is outdated'
            : '$outdatedSummaries summaries are outdated',
      );
    }
    if (overdueTasks > 0) {
      out.add(
        overdueTasks == 1
            ? '1 task is overdue'
            : '$overdueTasks tasks are overdue',
      );
    }
    return out;
  }

  String get headline {
    if (isQuiet) {
      return 'No unreviewed facts or outdated summaries.';
    }
    return lines.first;
  }

  @override
  List<Object?> get props => <Object?>[
    patients,
    unreviewedFacts,
    outdatedSummaries,
    overdueTasks,
  ];
}

class RoundChangedBlock extends Equatable {
  const RoundChangedBlock({
    required this.status,
    this.message,
    this.computedInCode = true,
    this.newFacts = const <Map<String, dynamic>>[],
    this.trends = const <Map<String, dynamic>>[],
    this.conflicts = const <Map<String, dynamic>>[],
    this.nothingNew,
  });

  factory RoundChangedBlock.fromJson(Map<String, dynamic> json) {
    return RoundChangedBlock(
      status: Json.string(json['status'], 'ok'),
      message: Json.stringOrNull(json['message']),
      computedInCode: Json.boolean(json['computed_in_code'], true),
      newFacts: Json.maps(json['new_facts']),
      trends: Json.maps(json['trends']),
      conflicts: Json.maps(json['conflicts']),
      nothingNew: json['nothing_new'] is bool
          ? json['nothing_new'] as bool
          : null,
    );
  }

  final String status;
  final String? message;
  final bool computedInCode;
  final List<Map<String, dynamic>> newFacts;
  final List<Map<String, dynamic>> trends;
  final List<Map<String, dynamic>> conflicts;
  final bool? nothingNew;

  String get summaryLine {
    if (message != null && message!.isNotEmpty) return message!;
    if (nothingNew == true) return 'Nothing new since the last reviewed summary.';
    if (newFacts.isEmpty) return 'No new confirmed facts since baseline.';
    final int n = newFacts.length;
    return n == 1
        ? '1 new confirmed fact since baseline'
        : '$n new confirmed facts since baseline';
  }

  @override
  List<Object?> get props => <Object?>[status, message, nothingNew, newFacts];
}

class RoundTaskItem extends Equatable {
  const RoundTaskItem({
    required this.id,
    required this.text,
    this.owner = '',
    this.due = '',
    this.state = '',
    this.dueToday = false,
    this.overdue = false,
  });

  factory RoundTaskItem.fromJson(Map<String, dynamic> json) {
    return RoundTaskItem(
      id: Json.string(json['id']),
      text: Json.string(json['text']),
      owner: Json.string(json['owner']),
      due: Json.string(json['due']),
      state: Json.string(json['state']),
      dueToday: Json.boolean(json['due_today']),
      overdue: Json.boolean(json['overdue']),
    );
  }

  final String id;
  final String text;
  final String owner;
  final String due;
  final String state;
  final bool dueToday;
  final bool overdue;

  @override
  List<Object?> get props => <Object?>[id, text, overdue, dueToday];
}

class RoundProblemItem extends Equatable {
  const RoundProblemItem({
    required this.id,
    required this.label,
    required this.state,
  });

  factory RoundProblemItem.fromJson(Map<String, dynamic> json) {
    return RoundProblemItem(
      id: Json.string(json['id']),
      label: Json.string(json['label']),
      state: Json.string(json['state']),
    );
  }

  final String id;
  final String label;
  final String state;

  @override
  List<Object?> get props => <Object?>[id, label, state];
}

class RoundPendingItem extends Equatable {
  const RoundPendingItem({
    required this.factId,
    required this.label,
    required this.value,
    this.unit = '',
    this.sourceId,
    this.sourcePassage,
  });

  factory RoundPendingItem.fromJson(Map<String, dynamic> json) {
    return RoundPendingItem(
      factId: Json.string(json['fact_id']),
      label: Json.string(json['label']),
      value: Json.string(json['value']),
      unit: Json.string(json['unit']),
      sourceId: Json.stringOrNull(json['source_id']),
      sourcePassage: Json.stringOrNull(json['source_passage']),
    );
  }

  final String factId;
  final String label;
  final String value;
  final String unit;
  final String? sourceId;
  final String? sourcePassage;

  String get display => unit.isEmpty ? '$label · $value' : '$label · $value $unit';

  @override
  List<Object?> get props => <Object?>[factId, label, value];
}

/// One patient card inside the day brief.
class RoundPatientCard extends Equatable {
  const RoundPatientCard({
    required this.patientId,
    required this.displayName,
    this.room = '',
    this.ageBand = '',
    this.sex = '',
    this.sortOrder,
    this.summaryState = '',
    this.unreviewedFacts = 0,
    this.whatChanged = const RoundChangedBlock(status: 'ok'),
    this.trends = const <Map<String, dynamic>>[],
    this.conflicts = const <Map<String, dynamic>>[],
    this.pendingItems = const <RoundPendingItem>[],
    this.tasks = const <RoundTaskItem>[],
    this.reminders = const <RoundReminder>[],
    this.yesterdayComparisons = const <YesterdayComparison>[],
    this.missingInformation = const <String>[],
    this.planToday,
    this.problems = const <RoundProblemItem>[],
  });

  factory RoundPatientCard.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> plan = Json.map(json['plan_today']);
    return RoundPatientCard(
      patientId: Json.string(json['patient_id']),
      displayName: Json.string(json['display_name']),
      room: Json.string(json['room']),
      ageBand: Json.string(json['age_band']),
      sex: Json.string(json['sex']),
      sortOrder: Json.integerOrNull(json['sort_order']),
      summaryState: Json.string(json['summary_state']),
      unreviewedFacts: Json.integer(json['unreviewed_facts']),
      whatChanged: RoundChangedBlock.fromJson(Json.map(json['what_changed'])),
      trends: Json.maps(json['trends']),
      conflicts: Json.maps(json['conflicts']),
      pendingItems: Json.maps(
        json['pending_items'],
      ).map(RoundPendingItem.fromJson).toList(),
      tasks: Json.maps(json['tasks']).map(RoundTaskItem.fromJson).toList(),
      reminders: Json.maps(
        json['reminders'],
      ).map(RoundReminder.fromJson).toList(),
      yesterdayComparisons: Json.maps(
        json['yesterday_comparisons'],
      ).map(YesterdayComparison.fromJson).toList(),
      missingInformation: Json.strings(json['missing_information']),
      planToday: plan.isEmpty ? null : Json.stringOrNull(plan['text']),
      problems: Json.maps(
        json['problems'],
      ).map(RoundProblemItem.fromJson).toList(),
    );
  }

  final String patientId;
  final String displayName;
  final String room;
  final String ageBand;
  final String sex;
  final int? sortOrder;
  final String summaryState;
  final int unreviewedFacts;
  final RoundChangedBlock whatChanged;
  final List<Map<String, dynamic>> trends;
  final List<Map<String, dynamic>> conflicts;
  final List<RoundPendingItem> pendingItems;
  final List<RoundTaskItem> tasks;
  final List<RoundReminder> reminders;
  final List<YesterdayComparison> yesterdayComparisons;
  final List<String> missingInformation;
  final String? planToday;
  final List<RoundProblemItem> problems;

  int get overdueTaskCount =>
      tasks.where((RoundTaskItem t) => t.overdue).length;

  String get metaLine {
    final List<String> parts = <String>[];
    if (room.isNotEmpty) parts.add('Room $room');
    if (ageBand.isNotEmpty) parts.add(ageBand);
    if (sex.isNotEmpty) parts.add(sex);
    if (summaryState.isNotEmpty) parts.add(summaryState);
    return parts.join(' · ');
  }

  @override
  List<Object?> get props => <Object?>[patientId, displayName, sortOrder];
}

/// Full `GET /round/brief` payload.
class RoundBrief extends Equatable {
  const RoundBrief({
    required this.date,
    required this.counts,
    required this.patients,
    this.assembledInCode = true,
    this.ordering = 'sort_order_then_room',
    this.note = '',
  });

  factory RoundBrief.fromJson(Map<String, dynamic> json) {
    final List<RoundPatientCard> patients = Json.maps(
      json['patients'],
    ).map(RoundPatientCard.fromJson).toList();
    final int overdue = patients.fold<int>(
      0,
      (int sum, RoundPatientCard c) => sum + c.overdueTaskCount,
    );
    return RoundBrief(
      date: Json.string(json['date']),
      assembledInCode: Json.boolean(json['assembled_in_code'], true),
      ordering: Json.string(json['ordering'], 'sort_order_then_room'),
      counts: RoundBriefCounts.fromJson(
        Json.map(json['counts']),
        overdueTasks: overdue,
      ),
      patients: patients,
      note: Json.string(json['note']),
    );
  }

  final String date;
  final bool assembledInCode;
  final String ordering;
  final RoundBriefCounts counts;
  final List<RoundPatientCard> patients;
  final String note;

  @override
  List<Object?> get props => <Object?>[date, counts, patients];
}
