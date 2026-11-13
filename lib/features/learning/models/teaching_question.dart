import 'package:equatable/equatable.dart';
import 'package:round_ai/core/utils/json_utils.dart';

const String curatedHighYieldLabel = 'Curated high-yield';

class McqOption extends Equatable {
  const McqOption({required this.letter, required this.text});

  final String letter;
  final String text;

  @override
  List<Object?> get props => <Object?>[letter, text];
}

/// One learner-facing question. No answer key until submit.
class TeachingQuestion extends Equatable {
  const TeachingQuestion({
    required this.mcqId,
    required this.topic,
    required this.topicKey,
    required this.vignette,
    required this.question,
    required this.options,
    this.difficulty = '',
    this.stage = '',
    this.status = '',
    this.source = '',
    this.notice = '',
    this.learnerLabel = '',
    this.bank = true,
    this.adminReviewQueue = false,
  });

  factory TeachingQuestion.fromJson(Map<String, dynamic> json) {
    return TeachingQuestion(
      mcqId: Json.string(json['mcq_id'] ?? json['id']),
      topic: Json.string(json['topic']),
      topicKey: Json.string(json['topic_key']),
      vignette: Json.string(json['vignette']),
      question: Json.string(json['question'] ?? json['lead_in']),
      options: parseOptions(json['options']),
      difficulty: Json.string(json['difficulty']),
      stage: Json.string(json['stage']),
      status: Json.string(json['status']),
      source: Json.string(json['source']),
      notice: Json.string(json['notice']),
      learnerLabel: Json.string(json['learner_label']),
      bank: Json.boolean(json['bank'], true),
      adminReviewQueue: Json.boolean(json['admin_review_queue']),
    );
  }

  /// Options may arrive as `{A:…,B:…}` or as a list.
  static List<McqOption> parseOptions(Object? raw) {
    if (raw is Map) {
      final List<McqOption> out = <McqOption>[];
      for (final String letter in const <String>['A', 'B', 'C', 'D', 'E']) {
        final Object? text = raw[letter];
        if (text == null) continue;
        final String t = text.toString().trim();
        if (t.isEmpty) continue;
        out.add(McqOption(letter: letter, text: t));
      }
      return out;
    }
    if (raw is List) {
      return <McqOption>[
        for (int i = 0; i < raw.length && i < 5; i++)
          McqOption(
            letter: String.fromCharCode(65 + i),
            text: raw[i].toString(),
          ),
      ];
    }
    return const <McqOption>[];
  }

  final String mcqId;
  final String topic;
  final String topicKey;
  final String vignette;
  final String question;
  final List<McqOption> options;
  final String difficulty;
  final String stage;
  final String status;
  final String source;
  final String notice;
  final String learnerLabel;
  final bool bank;
  final bool adminReviewQueue;

  bool get isUnreviewed =>
      !bank ||
      status == 'ai_generated_unreviewed' ||
      learnerLabel.toLowerCase().contains('unreviewed');

  /// Learners must never see reported / retired / draft bank items.
  bool get isLearnerSafe =>
      status == 'approved' || status == 'ai_generated_unreviewed';

  @override
  List<Object?> get props => <Object?>[mcqId, topic, status, bank];
}

class TeachingQuestionsResult extends Equatable {
  const TeachingQuestionsResult({
    required this.topic,
    required this.topicKey,
    required this.questions,
    this.bankServed = 0,
    this.generated = 0,
    this.note = '',
  });

  factory TeachingQuestionsResult.fromJson(Map<String, dynamic> json) {
    final List<TeachingQuestion> qs = Json.maps(json['questions'])
        .map(TeachingQuestion.fromJson)
        .where((TeachingQuestion q) => q.isLearnerSafe && q.mcqId.isNotEmpty)
        .toList();
    return TeachingQuestionsResult(
      topic: Json.string(json['topic']),
      topicKey: Json.string(json['topic_key']),
      questions: qs,
      bankServed: Json.integer(json['bank_served']),
      generated: Json.integer(json['generated']),
      note: Json.string(json['note']),
    );
  }

  final String topic;
  final String topicKey;
  final List<TeachingQuestion> questions;
  final int bankServed;
  final int generated;
  final String note;

  @override
  List<Object?> get props => <Object?>[topic, questions];
}

class McqAnswerResult extends Equatable {
  const McqAnswerResult({
    required this.correct,
    required this.correctAnswer,
    this.explanation = '',
    this.optionExplanations = const <String, String>{},
    this.learningObjective = '',
    this.nextReviewAt,
    this.references = const <String>[],
  });

  factory McqAnswerResult.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> opts = Json.map(json['option_explanations']);
    final Map<String, String> explained = <String, String>{};
    opts.forEach((String k, dynamic v) {
      final String t = v?.toString() ?? '';
      if (t.isNotEmpty) explained[k] = t;
    });
    final List<String> refs = <String>[];
    final Object? evidence = json['evidence'] ?? json['references'];
    if (evidence is List) {
      for (final Object? e in evidence) {
        if (e is Map) {
          final String pmid = Json.string(e['pmid']);
          if (pmid.isNotEmpty) refs.add(pmid);
        } else {
          final String s = Json.string(e);
          if (s.isNotEmpty) refs.add(s);
        }
      }
    }
    return McqAnswerResult(
      correct: Json.boolean(json['correct']),
      correctAnswer: Json.string(json['correct_answer']).toUpperCase(),
      explanation: Json.string(json['explanation']),
      optionExplanations: explained,
      learningObjective: Json.string(json['learning_objective']),
      nextReviewAt: Json.date(json['next_review_at']),
      references: refs,
    );
  }

  final bool correct;
  final String correctAnswer;
  final String explanation;
  final Map<String, String> optionExplanations;
  final String learningObjective;
  final DateTime? nextReviewAt;
  final List<String> references;

  @override
  List<Object?> get props => <Object?>[correct, correctAnswer];
}

class ReviewQueueItem extends Equatable {
  const ReviewQueueItem({
    required this.mcqId,
    required this.topic,
    this.nextReviewAt,
    this.reviewStage,
  });

  factory ReviewQueueItem.fromJson(Map<String, dynamic> json) {
    return ReviewQueueItem(
      mcqId: Json.string(json['mcq_id']),
      topic: Json.string(json['topic']),
      nextReviewAt: Json.date(json['next_review_at']),
      reviewStage: Json.integerOrNull(json['review_stage']),
    );
  }

  final String mcqId;
  final String topic;
  final DateTime? nextReviewAt;
  final int? reviewStage;

  /// Spaced intervals are 1 / 3 / 7 days.
  String get stageLabel {
    switch (reviewStage) {
      case 0:
        return 'Due · 1-day interval';
      case 1:
        return 'Due · 3-day interval';
      case 2:
        return 'Due · 7-day interval';
      default:
        return 'Due for review';
    }
  }

  @override
  List<Object?> get props => <Object?>[mcqId, topic, nextReviewAt];
}
