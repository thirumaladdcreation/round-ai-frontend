import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/patient/models/evidence_card.dart';

/// What `POST /patients/:id/evidence` returns: the studies the search
/// retrieved and how it was run. Nothing here comes from model memory, so an
/// empty list stays empty.
class EvidenceResult extends Equatable {
  const EvidenceResult({
    required this.envelope,
    this.topic = '',
    this.cards = const <EvidenceCard>[],
    this.retrieval,
  });

  factory EvidenceResult.fromEnvelope(AiEnvelope envelope) {
    final Map<String, dynamic> content = envelope.content;
    final Object? rawRetrieval = content['retrieval'];
    // Backend shape: `top` / `more` / `older` (see orchestrator runEvidence).
    final List<Map<String, dynamic>> rawCards = <Map<String, dynamic>>[
      ...Json.maps(content['top']),
      ...Json.maps(content['more']),
      ...Json.maps(content['older']),
      ...Json.maps(
        content['evidence'] ??
            content['evidence_cards'] ??
            content['cards'] ??
            content['studies'] ??
            content['recent'],
      ),
    ];
    final Set<String> seen = <String>{};
    final List<EvidenceCard> cards = <EvidenceCard>[];
    for (final Map<String, dynamic> row in rawCards) {
      final EvidenceCard card = EvidenceCard.fromJson(row);
      final String key = card.id.isNotEmpty ? card.id : card.title;
      if (key.isEmpty || !seen.add(key)) continue;
      cards.add(card);
    }
    return EvidenceResult(
      envelope: envelope,
      topic: Json.string(content['topic']),
      cards: cards,
      retrieval: rawRetrieval is Map
          ? EvidenceRetrieval.fromJson(Json.map(rawRetrieval))
          : EvidenceRetrieval.fromJson(content),
    );
  }

  final AiEnvelope envelope;

  /// The topic the search ran on, as the backend reports it.
  final String topic;
  final List<EvidenceCard> cards;
  final EvidenceRetrieval? retrieval;

  bool get isEmpty => cards.isEmpty;

  @override
  List<Object?> get props => <Object?>[envelope, topic, cards, retrieval];
}
