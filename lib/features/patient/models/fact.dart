import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

enum FactStatus { pending, confirmed, rejected }

/// One chart fact. AI only uses facts a clinician has confirmed.
class Fact extends Equatable {
  const Fact({
    required this.id,
    required this.name,
    required this.value,
    required this.status,
    this.unit,
    this.eventTime,
    this.sourceId,
    this.passage,
    this.qualifier,
    this.warnings = const <FactWarning>[],
  });

  factory Fact.fromJson(Map<String, dynamic> json) {
    final String status = Json.string(
      json['reviewer_status'] ?? json['status'],
    ).toLowerCase();
    final List<FactWarning> warnings = <FactWarning>[];
    final Object? rawWarnings = json['warnings'] ?? json['warnings_json'];
    if (rawWarnings is List) {
      for (final Object? e in rawWarnings) {
        if (e is Map) {
          warnings.add(FactWarning.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    } else if (rawWarnings is String && rawWarnings.trim().isNotEmpty) {
      // Already parsed on BE; ignore raw JSON string if present.
    }
    return Fact(
      id: Json.string(json['id']),
      name: Json.string(json['name'] ?? json['label'] ?? json['kind']),
      value: Json.string(json['value']),
      unit: Json.stringOrNull(json['unit']),
      // A missing time stays null and is shown as Unknown.
      eventTime: Json.date(json['event_time']),
      status: switch (status) {
        'confirmed' => FactStatus.confirmed,
        'rejected' => FactStatus.rejected,
        _ => FactStatus.pending,
      },
      sourceId: Json.stringOrNull(json['source_id']),
      passage: Json.stringOrNull(
        json['passage'] ?? json['source_passage'],
      ),
      qualifier: Json.stringOrNull(json['qualifier']),
      warnings: warnings,
    );
  }

  final String id;
  final String name;
  final String value;
  final String? unit;
  final DateTime? eventTime;
  final FactStatus status;
  final String? sourceId;
  final String? passage;

  /// Context that must appear in the source passage (e.g. on room air).
  final String? qualifier;
  final List<FactWarning> warnings;

  Fact copyWith({
    String? name,
    String? value,
    String? unit,
    String? qualifier,
    DateTime? eventTime,
  }) {
    return Fact(
      id: id,
      name: name ?? this.name,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      eventTime: eventTime ?? this.eventTime,
      status: status,
      sourceId: sourceId,
      passage: passage,
      qualifier: qualifier ?? this.qualifier,
      warnings: warnings,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    value,
    unit,
    eventTime,
    status,
    qualifier,
    warnings,
  ];
}

class FactWarning extends Equatable {
  const FactWarning({required this.code, required this.message});

  factory FactWarning.fromJson(Map<String, dynamic> json) {
    return FactWarning(
      code: Json.string(json['code']),
      message: Json.string(json['message']),
    );
  }

  final String code;
  final String message;

  @override
  List<Object?> get props => <Object?>[code, message];
}

/// Dictation A&P proposal from extract_facts.
class PlanProposal extends Equatable {
  const PlanProposal({
    required this.title,
    required this.planText,
    this.problemId,
    this.assessmentText,
    this.isNewProblem = false,
    this.transcriptSpan,
  });

  factory PlanProposal.fromJson(Map<String, dynamic> json) {
    return PlanProposal(
      title: Json.string(json['title'] ?? json['label']),
      planText: Json.string(json['plan_text'] ?? json['plan']),
      problemId: Json.stringOrNull(json['problem_id']),
      assessmentText: Json.stringOrNull(
        json['assessment_text'] ?? json['assessment'],
      ),
      isNewProblem: json['is_new_problem'] == true,
      transcriptSpan: Json.stringOrNull(json['transcript_span']),
    );
  }

  final String title;
  final String planText;
  final String? problemId;
  final String? assessmentText;
  final bool isNewProblem;
  final String? transcriptSpan;

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'plan_text': planText,
    'problem_id': problemId,
    'assessment_text': assessmentText,
    'is_new_problem': isNewProblem,
  };

  @override
  List<Object?> get props => <Object?>[title, planText, problemId];
}

/// What the source drawer shows: `GET /facts/:id/source`.
class SourcePassage extends Equatable {
  const SourcePassage({
    required this.passage,
    required this.sourceTitle,
    this.sourceTime,
  });

  factory SourcePassage.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> source = Json.map(json['source']);
    return SourcePassage(
      passage: Json.string(json['passage']),
      // Backend nests title/time under `source`; older shapes stay flat.
      sourceTitle: Json.string(
        json['source_title'] ?? source['title'] ?? source['kind'],
      ),
      sourceTime: Json.date(
        json['source_time'] ?? source['event_time'] ?? source['uploaded_at'],
      ),
    );
  }

  final String passage;
  final String sourceTitle;
  final DateTime? sourceTime;

  @override
  List<Object?> get props => <Object?>[passage, sourceTitle, sourceTime];
}
