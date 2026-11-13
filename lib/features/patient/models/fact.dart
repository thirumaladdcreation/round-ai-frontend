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
  });

  factory Fact.fromJson(Map<String, dynamic> json) {
    final String status = Json.string(
      json['reviewer_status'] ?? json['status'],
    ).toLowerCase();
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

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    value,
    unit,
    eventTime,
    status,
  ];
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
