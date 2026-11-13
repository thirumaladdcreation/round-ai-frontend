import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';

/// Oral presentation target from the backend validator.
const int presentationWordMin = 150;
const int presentationWordMax = 220;

const String presentationReviewLabel =
    'AI draft oral presentation. Review required before use.';

class PresentationDraft extends Equatable {
  const PresentationDraft({
    required this.sentences,
    required this.planSentences,
    required this.spokenText,
    required this.wordCount,
    this.wordBudgetMin = presentationWordMin,
    this.wordBudgetMax = presentationWordMax,
    this.estimatedSeconds = 0,
    this.targetDuration = '60-90 seconds',
    this.flags = const <String>[],
    this.missingInformation = const <String>[],
    this.label = presentationReviewLabel,
  });

  factory PresentationDraft.fromContent(Map<String, dynamic> content) {
    final Map<String, dynamic> budget = Json.map(content['word_budget']);
    final List<String> flags = <String>[];
    final Object? rawFlags = content['flags'];
    if (rawFlags is List) {
      for (final Object? f in rawFlags) {
        if (f is Map) {
          final String code = Json.string(f['code']);
          if (code.isNotEmpty) flags.add(code);
        } else {
          final String s = Json.string(f);
          if (s.isNotEmpty) flags.add(s);
        }
      }
    }
    return PresentationDraft(
      sentences: Claim.list(content['sentences']),
      planSentences: Claim.list(content['plan_sentences']),
      spokenText: Json.string(content['spoken_text']),
      wordCount: Json.integer(content['word_count']),
      wordBudgetMin: Json.integer(budget['min'], presentationWordMin),
      wordBudgetMax: Json.integer(budget['max'], presentationWordMax),
      estimatedSeconds: Json.integer(content['estimated_seconds']),
      targetDuration: Json.string(
        content['target_duration'],
        '60-90 seconds',
      ),
      flags: flags,
      missingInformation: Json.strings(content['missing_information']),
      label: Json.string(content['label'], presentationReviewLabel),
    );
  }

  final List<Claim> sentences;
  final List<Claim> planSentences;
  final String spokenText;
  final int wordCount;
  final int wordBudgetMin;
  final int wordBudgetMax;
  final int estimatedSeconds;
  final String targetDuration;
  final List<String> flags;
  final List<String> missingInformation;
  final String label;

  bool get inBudget =>
      wordCount >= wordBudgetMin && wordCount <= wordBudgetMax;

  String get wordCountLabel =>
      '$wordCount words (target $wordBudgetMin–$wordBudgetMax)';

  List<Claim> get allSentences => <Claim>[...sentences, ...planSentences];

  @override
  List<Object?> get props => <Object?>[spokenText, wordCount, sentences];
}

/// Envelope plus parsed presentation content.
class PresentationResult extends Equatable {
  const PresentationResult({required this.envelope, required this.draft});

  factory PresentationResult.fromEnvelope(AiEnvelope envelope) {
    return PresentationResult(
      envelope: envelope,
      draft: PresentationDraft.fromContent(envelope.content),
    );
  }

  final AiEnvelope envelope;
  final PresentationDraft draft;

  String get artifactId => envelope.artifactId;
  bool get isReviewed => envelope.isReviewed;
  bool get requiresReview => envelope.requiresReview;

  @override
  List<Object?> get props => <Object?>[envelope, draft];
}
