import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/learning/models/mcq.dart';

/// A generated question together with the artifact it is saved as.
class McqDraft extends Equatable {
  const McqDraft({required this.envelope, required this.mcq});

  /// The question may be the whole `content` or sit inside it as `question`
  /// or `mcq`. Its id falls back to the artifact id.
  factory McqDraft.fromEnvelope(AiEnvelope envelope) {
    final Map<String, dynamic> content = envelope.content;
    Map<String, dynamic> body = content;
    for (final String key in const <String>['question', 'mcq']) {
      if (content[key] is Map) {
        body = Json.map(content[key]);
        break;
      }
    }
    final Map<String, dynamic> map = Map<String, dynamic>.of(body);
    if (Json.string(map['id'] ?? map['question_id']).isEmpty) {
      map['id'] = envelope.artifactId;
    }
    return McqDraft(envelope: envelope, mcq: Mcq.fromJson(map));
  }

  final AiEnvelope envelope;
  final Mcq mcq;

  /// A question is labelled "AI-generated, not yet reviewed" until someone
  /// reviews it.
  bool get isReviewed => envelope.isReviewed || mcq.isReviewed;

  @override
  List<Object?> get props => <Object?>[envelope, mcq];
}

/// What comes back after one choice is submitted. Until then the key is not
/// shown, even if the question arrived with one.
class McqReveal extends Equatable {
  const McqReveal({
    required this.correctIndex,
    this.explanation,
    this.optionExplanations = const <String>[],
    this.takeaway,
    this.references = const <String>[],
  });

  /// Reads a reveal from [json], falling back to what the question carried.
  /// Returns `null` when neither has the keyed answer.
  static McqReveal? from(Map<String, dynamic> json, Mcq question) {
    final int? fromLetter = Mcq.indexFromLetter(
      json['correct_answer'] ?? json['answer'],
    );
    final int? index =
        Json.integerOrNull(json['correct_index']) ??
        fromLetter ??
        question.correctIndex;
    if (index == null) return null;
    final List<String> perOption = Mcq.parseOptionExplanations(
      json['option_explanations'],
    );
    final List<String> references = Json.strings(json['references']);
    return McqReveal(
      correctIndex: index,
      explanation:
          Json.stringOrNull(json['explanation']) ?? question.explanation,
      optionExplanations: perOption.isEmpty
          ? question.optionExplanations
          : perOption,
      takeaway: Json.stringOrNull(json['takeaway']) ?? question.takeaway,
      references: references.isEmpty ? question.references : references,
    );
  }

  final int correctIndex;
  final String? explanation;
  final List<String> optionExplanations;
  final String? takeaway;
  final List<String> references;

  /// The explanation for option [index]. A list one shorter than the options
  /// leaves out the keyed answer, which has its own explanation.
  String? explanationFor(int index, int optionCount) {
    if (index == correctIndex && optionExplanations.length < optionCount) {
      return null;
    }
    if (optionExplanations.length == optionCount) {
      return optionExplanations[index];
    }
    if (optionExplanations.length == optionCount - 1) {
      final int at = index > correctIndex ? index - 1 : index;
      return at >= 0 && at < optionExplanations.length
          ? optionExplanations[at]
          : null;
    }
    return null;
  }

  @override
  List<Object?> get props => <Object?>[
    correctIndex,
    explanation,
    optionExplanations,
    takeaway,
    references,
  ];
}
