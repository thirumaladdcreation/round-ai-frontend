import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

/// One single-best-answer question. The answer key and explanations are
/// nullable because they are only shown after the learner submits.
class Mcq extends Equatable {
  const Mcq({
    required this.id,
    required this.topic,
    required this.vignette,
    required this.leadIn,
    required this.options,
    required this.difficulty,
    required this.reviewStatus,
    this.objective,
    this.correctIndex,
    this.explanation,
    this.optionExplanations = const <String>[],
    this.takeaway,
    this.references = const <String>[],
  });

  factory Mcq.fromJson(Map<String, dynamic> json) {
    final int? letterIndex = indexFromLetter(
      json['correct_answer'] ?? json['answer'],
    );
    return Mcq(
      id: Json.string(json['id'] ?? json['question_id'] ?? json['mcq_id']),
      topic: Json.string(json['topic']),
      vignette: Json.string(json['vignette']),
      // Backend public MCQ uses `question`; some shapes use `lead_in`.
      leadIn: Json.firstString(json, const <String>['lead_in', 'question']),
      options: parseOptions(json['options']),
      difficulty: Json.string(json['difficulty']),
      // Unreviewed generated questions are labeled as such.
      reviewStatus: Json.string(
        json['review_status'] ?? json['status'],
        'unreviewed',
      ),
      objective: Json.stringOrNull(json['learning_objective']),
      correctIndex: Json.integerOrNull(json['correct_index']) ?? letterIndex,
      optionExplanations: parseOptionExplanations(json['option_explanations']),
      explanation: Json.stringOrNull(json['explanation']),
      takeaway: Json.stringOrNull(json['takeaway']),
      references: Json.strings(json['references']),
    );
  }

  /// Backend stores options as `{A:…,E:…}`; older shapes use a list.
  static List<String> parseOptions(Object? raw) {
    if (raw is Map) {
      final List<String> out = <String>[];
      for (final String letter in const <String>['A', 'B', 'C', 'D', 'E']) {
        final Object? text = raw[letter];
        if (text == null) continue;
        final String t = text.toString().trim();
        if (t.isEmpty) continue;
        out.add(t);
      }
      return out;
    }
    return Json.strings(raw);
  }

  /// Explanations may be a letter map or a list aligned to options.
  static List<String> parseOptionExplanations(Object? raw) {
    if (raw is Map) {
      final List<String> out = <String>[];
      for (final String letter in const <String>['A', 'B', 'C', 'D', 'E']) {
        final Object? text = raw[letter];
        if (text == null) continue;
        out.add(text.toString().trim());
      }
      return out;
    }
    return Json.strings(raw);
  }

  /// Maps `A`–`E` (backend answer key) to a zero-based option index.
  static int? indexFromLetter(Object? value) {
    final String letter = Json.string(value).trim().toUpperCase();
    if (letter.length != 1) return null;
    final int code = letter.codeUnitAt(0) - 65;
    return code >= 0 && code < 26 ? code : null;
  }

  final String id;
  final String topic;
  final String vignette;
  final String leadIn;
  final List<String> options;
  final String difficulty;
  final String reviewStatus;
  final String? objective;
  final int? correctIndex;
  final String? explanation;
  final List<String> optionExplanations;
  final String? takeaway;
  final List<String> references;

  bool get isReviewed {
    final String s = reviewStatus.toLowerCase();
    return s == 'reviewed' || s == 'approved';
  }

  @override
  List<Object?> get props => <Object?>[id, topic, options, reviewStatus];
}
