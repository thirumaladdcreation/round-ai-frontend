import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

enum AiStatus { draft, partial }

enum ReviewState { draft, reviewed }

/// Where a statement comes from. Chart claims carry fact ids.
enum ClaimLabel { fromChart, aiInterpretation }

/// A statement with its sources. Tapping it opens the source drawer.
class Claim extends Equatable {
  const Claim({
    required this.text,
    required this.label,
    this.factIds = const <String>[],
    this.evidenceIds = const <String>[],
  });

  factory Claim.fromJson(Map<String, dynamic> json) {
    final String raw = Json.string(json['label']).toLowerCase();
    return Claim(
      text: Json.firstString(json, const <String>[
        'text',
        'statement',
        'claim',
      ]),
      label: raw.contains('chart')
          ? ClaimLabel.fromChart
          : ClaimLabel.aiInterpretation,
      factIds: Json.strings(json['fact_ids']),
      evidenceIds: Json.strings(json['evidence_ids']),
    );
  }

  /// A claim may arrive as an object or as plain text. Plain text has no
  /// sources, so it is labelled as interpretation, never as chart.
  static Claim parse(Object? json) {
    if (json is Map) return Claim.fromJson(Json.map(json));
    return Claim(text: Json.string(json), label: ClaimLabel.aiInterpretation);
  }

  static List<Claim> list(Object? value) {
    if (value is! List) return const <Claim>[];
    return value
        .map(Claim.parse)
        .where((Claim c) => c.text.isNotEmpty)
        .toList();
  }

  final String text;
  final ClaimLabel label;
  final List<String> factIds;
  final List<String> evidenceIds;

  String get labelText =>
      label == ClaimLabel.fromChart ? 'From chart' : 'AI interpretation';

  @override
  List<Object> get props => <Object>[text, label, factIds, evidenceIds];
}

/// One thing validation held back or flagged.
class ValidationIssue extends Equatable {
  const ValidationIssue({required this.message, this.code, this.section});

  factory ValidationIssue.fromJson(Object? json) {
    if (json is Map) {
      final Map<String, dynamic> map = Json.map(json);
      return ValidationIssue(
        message: Json.string(map['message']),
        code: Json.stringOrNull(map['code']),
        section: Json.stringOrNull(map['section']),
      );
    }
    return ValidationIssue(message: Json.string(json));
  }

  final String message;
  final String? code;
  final String? section;

  @override
  List<Object?> get props => <Object?>[message, code, section];
}

/// Common wrapper returned by every AI endpoint. What is inside [content]
/// depends on [operation]; each feature reads its own part of it.
class AiEnvelope extends Equatable {
  const AiEnvelope({
    required this.artifactId,
    required this.operation,
    required this.patientId,
    required this.contextRevision,
    required this.status,
    required this.reviewState,
    required this.outdated,
    required this.requiresReview,
    required this.provider,
    required this.model,
    required this.promptVersion,
    required this.generationMs,
    required this.createdAt,
    required this.content,
  });

  /// An envelope may come bare or inside { "artifact": {...} }.
  factory AiEnvelope.fromBody(Object? body) {
    Map<String, dynamic> map = Json.map(body);
    if (map['artifact'] is Map) map = Json.map(map['artifact']);
    return AiEnvelope.fromJson(map);
  }

  factory AiEnvelope.fromJson(Map<String, dynamic> json) {
    return AiEnvelope(
      artifactId: Json.string(json['artifact_id']),
      operation: Json.string(json['operation']),
      patientId: Json.string(json['patient_id']),
      contextRevision: Json.integer(json['context_revision']),
      status: Json.string(json['status']) == 'partial'
          ? AiStatus.partial
          : AiStatus.draft,
      reviewState: Json.string(json['review_state']) == 'reviewed'
          ? ReviewState.reviewed
          : ReviewState.draft,
      outdated: Json.boolean(json['outdated']),
      // A draft needs review unless the server says otherwise.
      requiresReview: Json.boolean(json['requires_review'], true),
      provider: Json.string(json['provider']),
      model: Json.string(json['model']),
      promptVersion: Json.string(json['prompt_version']),
      generationMs: Json.integer(json['generation_ms']),
      createdAt: Json.date(json['created_at']),
      content: Json.map(json['content']),
    );
  }

  final String artifactId;
  final String operation;
  final String patientId;
  final int contextRevision;
  final AiStatus status;
  final ReviewState reviewState;
  final bool outdated;
  final bool requiresReview;
  final String provider;
  final String model;
  final String promptVersion;
  final int generationMs;
  final DateTime? createdAt;
  final Map<String, dynamic> content;

  bool get isReviewed => reviewState == ReviewState.reviewed;
  bool get isPartial => status == AiStatus.partial;

  List<ValidationIssue> get validationIssues {
    final Object? raw = content['validation_issues'];
    if (raw is! List) return const <ValidationIssue>[];
    return raw.map(ValidationIssue.fromJson).toList();
  }

  @override
  List<Object?> get props => <Object?>[
    artifactId,
    operation,
    patientId,
    contextRevision,
    status,
    reviewState,
    outdated,
  ];
}
