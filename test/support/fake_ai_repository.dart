import 'dart:async';

import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/models/ask_reply.dart';
import 'package:round_ai/features/ai/repository/ai_repository.dart';
import 'package:round_ai/features/patient/models/fact.dart';

/// A summary envelope the way the backend sends it. [content] is the
/// `content` object.
AiEnvelope envelopeOf({
  String id = 'a1',
  String status = 'draft',
  String review = 'draft',
  bool outdated = false,
  Map<String, dynamic>? content,
  String createdAt = '2026-11-12T09:00:00Z',
}) {
  return AiEnvelope.fromJson(<String, dynamic>{
    'artifact_id': id,
    'operation': 'summarize_patient',
    'patient_id': 'p1',
    'context_revision': 3,
    'status': status,
    'review_state': review,
    'outdated': outdated,
    'requires_review': review != 'reviewed',
    'created_at': createdAt,
    'content': content ?? summaryContent(),
  });
}

Map<String, dynamic> summaryContent({
  List<Object>? sections,
  Object? truncated,
  List<Object>? issues,
}) {
  return <String, dynamic>{
    'one_liner': <String, Object>{
      'text': '72F with CHF and rising creatinine.',
      'label': 'From chart',
      'fact_ids': <String>['f1', 'f2'],
    },
    'sections':
        sections ??
        <Object>[
          <String, Object>{
            'key': 'course',
            'title': 'Hospital course',
            'claims': <Object>[
              <String, Object>{
                'text': 'Creatinine rose from 1.2 to 1.7.',
                'label': 'From chart',
                'fact_ids': <String>['f1'],
              },
              <String, Object>{
                'text': 'Likely cardiorenal.',
                'label': 'AI interpretation',
              },
            ],
          },
        ],
    'missing_information': <Object>["Today's exam"],
    'conflicts': <Object>[
      <String, Object>{'label': 'Weight', 'text': 'Two values differ'},
    ],
    'truncated': ?truncated,
    'validation_issues': issues ?? <Object>[],
  };
}

/// An [AiRepository] the tests drive. Every call is recorded.
class FakeAiRepository implements AiRepository {
  Result<AiEnvelope?> latest = const Ok<AiEnvelope?>(null);

  /// What `generateSummary` does. Replace it to fail or to wait.
  Future<Result<AiEnvelope>> Function(String key)? onGenerate;
  Result<AiEnvelope>? generated;
  Result<AiEnvelope>? reviewed;
  Result<AskReply>? asked;
  Future<Result<AskReply>> Function(String question, String? topic)? onAsk;
  final Map<String, Result<SourcePassage>> sources =
      <String, Result<SourcePassage>>{};

  final List<String> generateKeys = <String>[];
  final List<String> askKeys = <String>[];
  final List<String> askTopics = <String>[];
  final List<String> reviewed_ = <String>[];
  final List<String> sourceRequests = <String>[];
  int latestCalls = 0;
  CancelToken? lastToken;

  static Failure failure(
    String code, {
    int? status,
    Map<String, dynamic>? details,
  }) => ApiFailure(
    ApiError(code: code, message: 'raw', status: status, details: details),
  );

  @override
  Future<Result<AiEnvelope?>> latestSummary(String patientId) async {
    latestCalls++;
    return latest;
  }

  @override
  Future<Result<AiEnvelope>> generateSummary(
    String patientId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) {
    generateKeys.add(idempotencyKey);
    lastToken = cancelToken;
    final Future<Result<AiEnvelope>> Function(String)? handler = onGenerate;
    if (handler != null) return handler(idempotencyKey);
    return Future<Result<AiEnvelope>>.value(
      generated ?? Ok<AiEnvelope>(envelopeOf()),
    );
  }

  @override
  Future<Result<AiEnvelope>> markReviewed(String artifactId) async {
    reviewed_.add(artifactId);
    return reviewed ??
        Ok<AiEnvelope>(envelopeOf(id: artifactId, review: 'reviewed'));
  }

  @override
  Future<Result<SourcePassage>> factSource(String factId) async {
    sourceRequests.add(factId);
    return sources[factId] ??
        Ok<SourcePassage>(
          SourcePassage(
            passage: 'Cr 1.7 this morning',
            sourceTitle: 'Progress note',
            sourceTime: DateTime.utc(2026, 11, 12, 8),
          ),
        );
  }

  @override
  Future<Result<AskReply>> ask(
    String patientId, {
    required String question,
    required String idempotencyKey,
    String? topic,
    CancelToken? cancelToken,
  }) {
    askKeys.add(idempotencyKey);
    askTopics.add(topic ?? '');
    lastToken = cancelToken;
    final Future<Result<AskReply>> Function(String, String?)? handler = onAsk;
    if (handler != null) return handler(question, topic);
    return Future<Result<AskReply>>.value(
      asked ??
          const Ok<AskReply>(AskReply(status: AskStatus.ok, message: 'ok')),
    );
  }
}
