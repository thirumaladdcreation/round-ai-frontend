import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/patient/models/evidence_card.dart';

/// How the backend answered a question about one patient.
enum AskStatus { ok, refused, needsTopic }

/// `POST /patients/:id/ask`. Chart claims carry their sources. Evidence
/// cards come only from the retrieved list.
class AskReply extends Equatable {
  const AskReply({
    required this.status,
    this.message = '',
    this.claims = const <Claim>[],
    this.evidence = const <EvidenceCard>[],
    this.retrieval,
    this.partial = false,
    this.issueCount = 0,
  });

  factory AskReply.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> content = Json.map(json['content']);
    final AskStatus status = _status(json) ?? _status(content) ?? AskStatus.ok;
    final Object? rawEvidence =
        content['evidence'] ?? content['evidence_cards'] ?? content['cards'];
    final Object? rawRetrieval = content['retrieval'];
    return AskReply(
      status: status,
      message: Json.firstString(content, const <String>[
        'message',
        'answer',
        'text',
        'prompt',
      ]),
      claims: Claim.list(content['claims'] ?? content['chart_claims']),
      evidence: Json.maps(rawEvidence).map(EvidenceCard.fromJson).toList(),
      retrieval: rawRetrieval is Map
          ? EvidenceRetrieval.fromJson(Json.map(rawRetrieval))
          : null,
      partial: Json.string(json['status']) == 'partial',
      issueCount: content['validation_issues'] is List
          ? (content['validation_issues'] as List).length
          : 0,
    );
  }

  /// `status` may sit on the envelope or inside `content`. The envelope uses
  /// the same word for draft or partial, so only the three ask values count.
  static AskStatus? _status(Map<String, dynamic> map) {
    switch (Json.string(map['status']).toLowerCase()) {
      case 'ok':
        return AskStatus.ok;
      case 'refused':
        return AskStatus.refused;
      case 'needs_topic':
        return AskStatus.needsTopic;
    }
    return null;
  }

  final AskStatus status;
  final String message;
  final List<Claim> claims;
  final List<EvidenceCard> evidence;

  /// Set when an evidence search was run for this question.
  final EvidenceRetrieval? retrieval;
  final bool partial;
  final int issueCount;

  @override
  List<Object?> get props => <Object?>[
    status,
    message,
    claims,
    evidence,
    retrieval,
    partial,
  ];
}
