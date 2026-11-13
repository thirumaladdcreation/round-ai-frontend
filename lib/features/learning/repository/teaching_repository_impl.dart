import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_endpoints.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/utils/json_utils.dart';
import 'package:round_ai/features/learning/models/teaching_plan.dart';
import 'package:round_ai/features/learning/models/teaching_question.dart';
import 'package:round_ai/features/learning/models/teaching_reads.dart';
import 'package:round_ai/features/learning/repository/teaching_repository.dart';

class TeachingRepositoryImpl implements TeachingRepository {
  TeachingRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<TeachingPlan>> loadPlan({String? date}) async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.teachingPlan,
        queryParameters: <String, dynamic>{
          if (date != null && date.isNotEmpty) 'date': date,
        },
      );
      return Ok<TeachingPlan>(TeachingPlan.fromJson(Json.map(response.data)));
    } on ApiError catch (error) {
      return Err<TeachingPlan>(ApiFailure(error));
    }
  }

  @override
  Future<Result<TeachingQuestionsResult>> loadQuestions({
    required String topic,
    int count = 1,
    bool allowGenerate = false,
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.teachingQuestions,
        queryParameters: <String, dynamic>{
          'topic': topic,
          'count': count,
          if (allowGenerate) 'allow_generate': 'true',
        },
        options: allowGenerate
            ? Options(
                headers: <String, Object>{
                  IdempotencyKey.header:
                      idempotencyKey ?? IdempotencyKey.create(),
                },
              )
            : null,
        cancelToken: cancelToken,
      );
      return Ok<TeachingQuestionsResult>(
        TeachingQuestionsResult.fromJson(Json.map(response.data)),
      );
    } on ApiError catch (error) {
      return Err<TeachingQuestionsResult>(ApiFailure(error));
    }
  }

  @override
  Future<Result<TeachingQuestion>> loadQuestion(String mcqId) async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.mcqGet(mcqId),
      );
      final TeachingQuestion q = TeachingQuestion.fromJson(
        Json.map(response.data),
      );
      if (!q.isLearnerSafe) {
        return Err<TeachingQuestion>(
          ApiFailure(
            const ApiError(
              code: 'not_approved',
              message: 'This question is not approved for learners yet.',
              status: 403,
            ),
          ),
        );
      }
      return Ok<TeachingQuestion>(q);
    } on ApiError catch (error) {
      return Err<TeachingQuestion>(ApiFailure(error));
    }
  }

  @override
  Future<Result<McqAnswerResult>> answer({
    required String mcqId,
    required String choice,
    int? seconds,
  }) async {
    try {
      final Response<Object> response = await _client.post<Object>(
        ApiEndpoints.mcqAnswer(mcqId),
        data: <String, Object?>{
          'choice': choice.toUpperCase(),
          'seconds': ?seconds,
        },
      );
      return Ok<McqAnswerResult>(
        McqAnswerResult.fromJson(Json.map(response.data)),
      );
    } on ApiError catch (error) {
      return Err<McqAnswerResult>(ApiFailure(error));
    }
  }

  @override
  Future<Result<void>> report({required String mcqId, String? note}) async {
    try {
      await _client.post<Object>(
        ApiEndpoints.mcqReport(mcqId),
        data: <String, Object?>{
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      return const Ok<void>(null);
    } on ApiError catch (error) {
      return Err<void>(ApiFailure(error));
    }
  }

  @override
  Future<Result<TeachingReads>> loadReads({required String topic}) async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.teachingReads,
        queryParameters: <String, dynamic>{'topic': topic},
      );
      return Ok<TeachingReads>(
        TeachingReads.fromJson(Json.map(response.data)),
      );
    } on ApiError catch (error) {
      return Err<TeachingReads>(ApiFailure(error));
    }
  }

  @override
  Future<Result<GuidelineUpdatesFeed>> loadGuidelineUpdates() async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.teachingGuidelineUpdates,
      );
      return Ok<GuidelineUpdatesFeed>(
        GuidelineUpdatesFeed.fromJson(Json.map(response.data)),
      );
    } on ApiError catch (error) {
      return Err<GuidelineUpdatesFeed>(ApiFailure(error));
    }
  }

  @override
  Future<Result<List<ReviewQueueItem>>> loadReviewQueue() async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.learningReviewQueue,
      );
      final List<ReviewQueueItem> items;
      if (response.data is List) {
        items = Json.maps(response.data).map(ReviewQueueItem.fromJson).toList();
      } else {
        items = Json.itemsOf(
          response.data,
          'items',
        ).map(ReviewQueueItem.fromJson).toList();
      }
      return Ok<List<ReviewQueueItem>>(items);
    } on ApiError catch (error) {
      return Err<List<ReviewQueueItem>>(ApiFailure(error));
    }
  }

  @override
  Future<Result<List<ReadingListItem>>> loadReadingList() async {
    try {
      final Response<Object> response = await _client.get<Object>(
        ApiEndpoints.readingList,
      );
      final List<ReadingListItem> items = response.data is List
          ? Json.maps(response.data).map(ReadingListItem.fromJson).toList()
          : Json.itemsOf(
              response.data,
              'items',
            ).map(ReadingListItem.fromJson).toList();
      return Ok<List<ReadingListItem>>(items);
    } on ApiError catch (error) {
      return Err<List<ReadingListItem>>(ApiFailure(error));
    }
  }

  @override
  Future<Result<void>> saveToReadingList({
    required String pmid,
    String? title,
  }) async {
    try {
      await _client.post<Object>(
        ApiEndpoints.readingList,
        data: <String, Object?>{
          'pmid': pmid,
          if (title != null && title.isNotEmpty) 'title': title,
        },
      );
      return const Ok<void>(null);
    } on ApiError catch (error) {
      return Err<void>(ApiFailure(error));
    }
  }
}
