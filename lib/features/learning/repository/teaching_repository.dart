import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/learning/models/teaching_plan.dart';
import 'package:round_ai/features/learning/models/teaching_question.dart';
import 'package:round_ai/features/learning/models/teaching_reads.dart';

abstract class TeachingRepository {
  Future<Result<TeachingPlan>> loadPlan({String? date});

  Future<Result<TeachingQuestionsResult>> loadQuestions({
    required String topic,
    int count = 1,
    bool allowGenerate = false,
    String? idempotencyKey,
    CancelToken? cancelToken,
  });

  Future<Result<TeachingQuestion>> loadQuestion(String mcqId);

  Future<Result<McqAnswerResult>> answer({
    required String mcqId,
    required String choice,
    int? seconds,
  });

  Future<Result<void>> report({required String mcqId, String? note});

  Future<Result<TeachingReads>> loadReads({required String topic});

  Future<Result<GuidelineUpdatesFeed>> loadGuidelineUpdates();

  Future<Result<List<ReviewQueueItem>>> loadReviewQueue();

  Future<Result<List<ReadingListItem>>> loadReadingList();

  Future<Result<void>> saveToReadingList({
    required String pmid,
    String? title,
  });
}
