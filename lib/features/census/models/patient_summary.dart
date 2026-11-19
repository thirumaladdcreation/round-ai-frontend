import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

/// Summary state shown as the pill on a census row.
enum SummaryState {
  notGenerated('Not generated'),
  draftReady('Draft ready'),
  reviewed('Reviewed'),
  outdated('Outdated');

  const SummaryState(this.label);

  final String label;

  static SummaryState parse(Object? value) {
    switch (Json.string(value).toLowerCase().replaceAll('_', ' ')) {
      case 'draft ready':
        return SummaryState.draftReady;
      case 'reviewed':
        return SummaryState.reviewed;
      case 'outdated':
        return SummaryState.outdated;
    }
    return SummaryState.notGenerated;
  }
}

/// One row from `GET /patients`. Display names are fictional in dev.
class PatientSummary extends Equatable {
  const PatientSummary({
    required this.id,
    required this.teamId,
    required this.displayName,
    required this.room,
    required this.ageBand,
    required this.sex,
    required this.summaryState,
    required this.unreviewedFacts,
    required this.openTasks,
    this.sortOrder = 0,
    this.oneLiner = '',
    this.keyChanges = const <String>[],
  });

  factory PatientSummary.fromJson(Map<String, dynamic> json) {
    return PatientSummary(
      id: Json.string(json['id']),
      teamId: Json.string(json['team_id']),
      displayName: Json.string(json['display_name']),
      room: Json.string(json['room']),
      ageBand: Json.string(json['age_band']),
      sex: Json.string(json['sex']),
      summaryState: SummaryState.parse(json['summary_state']),
      unreviewedFacts: Json.integer(json['unreviewed_facts']),
      openTasks: Json.integer(json['open_tasks']),
      sortOrder: Json.integer(json['sort_order']),
      oneLiner: Json.string(json['one_liner']),
      keyChanges: Json.strings(json['key_changes']),
    );
  }

  /// Backend order: `sort_order`, then room. No AI ranking.
  static int compareCensus(PatientSummary a, PatientSummary b) {
    final int bySort = a.sortOrder.compareTo(b.sortOrder);
    if (bySort != 0) return bySort;
    return compareByRoom(a, b);
  }

  /// Orders rooms the way people read them: 412B before 509A, 9 before 10.
  /// A patient with no room goes last.
  static int compareByRoom(PatientSummary a, PatientSummary b) {
    if (a.room.isEmpty != b.room.isEmpty) return a.room.isEmpty ? 1 : -1;
    final RegExp parts = RegExp(r'^(\D*)(\d+)(.*)$');
    final RegExpMatch? left = parts.firstMatch(a.room);
    final RegExpMatch? right = parts.firstMatch(b.room);
    if (left == null || right == null) {
      return a.room.toLowerCase().compareTo(b.room.toLowerCase());
    }
    final int prefix = left
        .group(1)!
        .toLowerCase()
        .compareTo(right.group(1)!.toLowerCase());
    if (prefix != 0) return prefix;
    final int number = int.parse(
      left.group(2)!,
    ).compareTo(int.parse(right.group(2)!));
    if (number != 0) return number;
    return left
        .group(3)!
        .toLowerCase()
        .compareTo(right.group(3)!.toLowerCase());
  }

  /// Short line for rows, such as `70-79 · F · Room 509A`. Blank parts are
  /// left out rather than guessed.
  String get metaLine {
    return <String>[
      if (ageBand.isNotEmpty) ageBand,
      if (sex.isNotEmpty) sex,
      if (room.isNotEmpty) 'Room $room',
    ].join(' · ');
  }

  String get initials {
    return displayName
        .split(' ')
        .where((String part) => part.isNotEmpty)
        .map((String part) => part[0].toUpperCase())
        .take(2)
        .join();
  }

  final String id;
  final String teamId;
  final String displayName;
  final String room;
  final String ageBand;
  final String sex;
  final SummaryState summaryState;
  final int unreviewedFacts;
  final int openTasks;

  /// Manual census order from the backend. Lower comes first.
  final int sortOrder;

  /// Short clinical one-liner when the chart has problems/age.
  final String oneLiner;

  /// Human-readable key trends (e.g. creatinine change).
  final List<String> keyChanges;

  PatientSummary copyWith({
    String? displayName,
    String? room,
    String? ageBand,
    String? sex,
    SummaryState? summaryState,
    int? unreviewedFacts,
    int? openTasks,
    int? sortOrder,
    String? oneLiner,
    List<String>? keyChanges,
  }) {
    return PatientSummary(
      id: id,
      teamId: teamId,
      displayName: displayName ?? this.displayName,
      room: room ?? this.room,
      ageBand: ageBand ?? this.ageBand,
      sex: sex ?? this.sex,
      summaryState: summaryState ?? this.summaryState,
      unreviewedFacts: unreviewedFacts ?? this.unreviewedFacts,
      openTasks: openTasks ?? this.openTasks,
      sortOrder: sortOrder ?? this.sortOrder,
      oneLiner: oneLiner ?? this.oneLiner,
      keyChanges: keyChanges ?? this.keyChanges,
    );
  }

  @override
  List<Object> get props => <Object>[
    id,
    teamId,
    displayName,
    room,
    summaryState,
    unreviewedFacts,
    openTasks,
    sortOrder,
    oneLiner,
    keyChanges,
  ];
}
