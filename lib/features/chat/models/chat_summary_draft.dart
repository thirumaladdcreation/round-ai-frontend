import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';

/// Parsed `content` from `POST /channels/:id/summarize` (never auto-posted).
class ChatSummaryDraft extends Equatable {
  const ChatSummaryDraft({
    required this.envelope,
    required this.bullets,
    required this.openQuestions,
    required this.missingInformation,
    required this.channelId,
    required this.disclaimer,
  });

  factory ChatSummaryDraft.fromEnvelope(AiEnvelope envelope) {
    final Map<String, dynamic> c = envelope.content;
    final List<ChatSummaryBullet> bullets = <ChatSummaryBullet>[];
    final Object? rawBullets = c['bullets'];
    if (rawBullets is List) {
      for (final Object? item in rawBullets) {
        if (item is Map) {
          bullets.add(ChatSummaryBullet.fromJson(Json.map(item)));
        } else {
          final String text = Json.string(item);
          if (text.isNotEmpty) {
            bullets.add(ChatSummaryBullet(text: text));
          }
        }
      }
    }
    return ChatSummaryDraft(
      envelope: envelope,
      bullets: bullets,
      openQuestions: Json.strings(c['open_questions']),
      missingInformation: Json.strings(c['missing_information']),
      channelId: Json.string(c['channel_id']),
      disclaimer: Json.string(
        c['disclaimer'],
        'AI draft · review required. Not posted to the channel.',
      ),
    );
  }

  final AiEnvelope envelope;
  final List<ChatSummaryBullet> bullets;
  final List<String> openQuestions;
  final List<String> missingInformation;
  final String channelId;
  final String disclaimer;

  bool get requiresReview => envelope.requiresReview;

  @override
  List<Object?> get props => <Object?>[
    envelope.artifactId,
    bullets,
    openQuestions,
    missingInformation,
    channelId,
  ];
}

class ChatSummaryBullet extends Equatable {
  const ChatSummaryBullet({
    required this.text,
    this.messageIds = const <String>[],
  });

  factory ChatSummaryBullet.fromJson(Map<String, dynamic> json) {
    return ChatSummaryBullet(
      text: Json.string(json['text']),
      messageIds: Json.strings(json['message_ids']),
    );
  }

  final String text;
  final List<String> messageIds;

  @override
  List<Object> get props => <Object>[text, messageIds];
}
