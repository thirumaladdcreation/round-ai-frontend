import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/constants/app_constants.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/storage/session_store.dart';

import 'support/fake_adapter.dart';

Map<String, Object> _error(String code, [Map<String, Object>? details]) {
  return <String, Object>{
    'error': <String, Object>{
      'code': code,
      'message': 'server text that must not reach the screen',
      'details': ?details,
    },
  };
}

ApiClient _client(
  FakeAdapter adapter,
  SessionStore session, {
  Future<void> Function()? onUnauthorized,
}) {
  return ApiClient(
    session: session,
    onUnauthorized: onUnauthorized,
    dio: fakeDio(adapter),
  );
}

void main() {
  group('Authorization and 401', () {
    test('adds the bearer token', () async {
      final SessionStore session = SessionStore.memory();
      await session.save('tok-1', persist: false);
      final FakeAdapter adapter = FakeAdapter(
        (_) => const FakeReply(200, <String, Object>{'ok': true}),
      );
      await _client(adapter, session).get<Map<String, dynamic>>('/me');
      expect(adapter.requests.single.headers['Authorization'], 'Bearer tok-1');
    });

    test('a 401 clears the session through onUnauthorized', () async {
      final SessionStore session = SessionStore.memory();
      await session.save('tok-1', persist: true);
      int ended = 0;
      final FakeAdapter adapter = FakeAdapter(
        (_) => FakeReply(401, _error('unauthenticated')),
      );
      final ApiClient client = _client(
        adapter,
        session,
        onUnauthorized: () async {
          ended++;
          await session.clear();
        },
      );

      await expectLater(
        client.get<Map<String, dynamic>>('/patients'),
        throwsA(
          isA<ApiError>().having(
            (ApiError e) => e.kind,
            'kind',
            ApiErrorKind.unauthenticated,
          ),
        ),
      );
      expect(ended, 1);
      expect(session.hasToken, isFalse);
    });

    test('a failed login is bad credentials, not a session end', () async {
      final SessionStore session = SessionStore.memory();
      await session.save('old-token', persist: false);
      int ended = 0;
      final FakeAdapter adapter = FakeAdapter(
        (_) => FakeReply(401, _error('bad_credentials')),
      );
      final ApiClient client = _client(
        adapter,
        session,
        onUnauthorized: () async => ended++,
      );

      await expectLater(
        client.post<Map<String, dynamic>>(
          '/auth/login',
          data: <String, Object>{},
        ),
        throwsA(
          isA<ApiError>().having(
            (ApiError e) => e.kind,
            'kind',
            ApiErrorKind.badCredentials,
          ),
        ),
      );
      expect(ended, 0);
      expect(adapter.requests.single.headers['Authorization'], isNull);
    });

    test('a 401 with no token does not trigger sign-out', () async {
      int ended = 0;
      final FakeAdapter adapter = FakeAdapter(
        (_) => FakeReply(401, _error('unauthenticated')),
      );
      final ApiClient client = _client(
        adapter,
        SessionStore.memory(),
        onUnauthorized: () async => ended++,
      );
      await expectLater(
        client.get<Map<String, dynamic>>('/me'),
        throwsA(isA<ApiError>()),
      );
      expect(ended, 0);
    });
  });

  group('Error mapping', () {
    final Map<String, ApiErrorKind> codes = <String, ApiErrorKind>{
      'unauthenticated': ApiErrorKind.unauthenticated,
      'bad_credentials': ApiErrorKind.badCredentials,
      'access_denied': ApiErrorKind.accessDenied,
      'no_reviewed_facts': ApiErrorKind.noReviewedFacts,
      'outdated': ApiErrorKind.outdated,
      'unresolved_flags': ApiErrorKind.unresolvedFlags,
      'placeholders_remaining': ApiErrorKind.placeholdersRemaining,
      'ai_disabled': ApiErrorKind.aiDisabled,
      'daily_limit': ApiErrorKind.dailyLimit,
      'ai_unavailable': ApiErrorKind.aiUnavailable,
      'ai_invalid_output': ApiErrorKind.aiInvalidOutput,
      'evidence_retrieval_failed': ApiErrorKind.evidenceRetrievalFailed,
      'query_not_safe': ApiErrorKind.querySafety,
      'too_large': ApiErrorKind.tooLarge,
      'mime_not_allowed': ApiErrorKind.mimeNotAllowed,
      'empty_file': ApiErrorKind.emptyFile,
      'not_approved': ApiErrorKind.notApproved,
      'not_confirmable': ApiErrorKind.notConfirmable,
      'team_required': ApiErrorKind.teamRequired,
      'topic_required': ApiErrorKind.topicRequired,
      'no_problems': ApiErrorKind.needsProblem,
      'problem_not_selected': ApiErrorKind.needsProblem,
      'chat_disabled': ApiErrorKind.chatDisabled,
      'rate_limited': ApiErrorKind.rateLimited,
      'duplicate_message': ApiErrorKind.duplicateMessage,
      'too_long': ApiErrorKind.messageTooLong,
      'empty_thread': ApiErrorKind.emptyThread,
      'archived': ApiErrorKind.channelArchived,
    };

    codes.forEach((String code, ApiErrorKind kind) {
      test('$code maps to $kind and never shows server text', () {
        final ApiError error = ApiError.fromResponse(400, _error(code));
        expect(error.kind, kind);
        expect(error.userMessage, isNot(contains('server text')));
        expect(error.toString(), isNot(contains('server text')));
      });
    });

    test('unknown codes fall back to the status', () {
      expect(
        ApiError.fromResponse(429, _error('mystery')).kind,
        ApiErrorKind.rateLimited,
      );
      expect(
        ApiError.fromResponse(403, _error('mystery')).kind,
        ApiErrorKind.accessDenied,
      );
      expect(
        ApiError.fromResponse(500, <String, Object>{'x': 1}).kind,
        ApiErrorKind.other,
      );
    });

    test('keeps details and the section list', () {
      final ApiError error = ApiError.fromResponse(
        409,
        _error('placeholders_remaining', <String, Object>{
          'sections': <String>['plan', 'exam'],
        }),
      );
      expect(error.sections, <String>['plan', 'exam']);
    });

    test('retry applies to generation and connection failures only', () {
      expect(
        ApiError.fromResponse(502, _error('ai_unavailable')).isRetryable,
        isTrue,
      );
      expect(
        ApiError.fromResponse(409, _error('outdated')).isRetryable,
        isFalse,
      );
      expect(const ApiError.timeout().isRetryable, isTrue);
    });

    test('connection problems become network and timeout errors', () {
      final RequestOptions options = RequestOptions(path: '/x');
      expect(
        ApiClient.mapDioError(
          DioException.connectionError(requestOptions: options, reason: 'x'),
        ).kind,
        ApiErrorKind.network,
      );
      expect(
        ApiClient.mapDioError(
          DioException.receiveTimeout(
            timeout: const Duration(seconds: 1),
            requestOptions: options,
          ),
        ).kind,
        ApiErrorKind.timeout,
      );
      expect(
        ApiClient.mapDioError(
          DioException.requestCancelled(
            requestOptions: options,
            reason: 'user',
          ),
        ).kind,
        ApiErrorKind.cancelled,
      );
    });
  });

  group('AI calls', () {
    test('send the idempotency key and use the long timeout', () async {
      final FakeAdapter adapter = FakeAdapter(
        (_) => const FakeReply(200, <String, Object>{'artifact_id': 'a1'}),
      );
      final ApiClient client = _client(adapter, SessionStore.memory());
      final String key = IdempotencyKey.create();

      await client.postAi<Map<String, dynamic>>(
        '/patients/p1/summary',
        idempotencyKey: key,
        data: <String, Object>{'date': '2026-11-12'},
      );

      final RequestOptions sent = adapter.requests.single;
      expect(sent.headers[IdempotencyKey.header], key);
      expect(sent.receiveTimeout, AppConstants.aiReceiveTimeout);
    });

    test('a retry reuses the same key', () async {
      int calls = 0;
      final FakeAdapter adapter = FakeAdapter((_) {
        calls++;
        return calls == 1
            ? FakeReply(502, _error('ai_unavailable'))
            : const FakeReply(200, <String, Object>{'artifact_id': 'a1'});
      });
      final ApiClient client = _client(adapter, SessionStore.memory());
      final String key = IdempotencyKey.create();

      await expectLater(
        client.postAi<Map<String, dynamic>>('/x', idempotencyKey: key),
        throwsA(isA<ApiError>()),
      );
      await client.postAi<Map<String, dynamic>>('/x', idempotencyKey: key);

      expect(
        adapter.requests.map(
          (RequestOptions r) => r.headers[IdempotencyKey.header],
        ),
        <Object?>[key, key],
      );
    });

    test('normal calls keep the short timeout and no key', () async {
      final FakeAdapter adapter = FakeAdapter(
        (_) => const FakeReply(200, <String, Object>{}),
      );
      final ApiClient client = _client(adapter, SessionStore.memory());
      await client.get<Map<String, dynamic>>('/patients');
      expect(adapter.requests.single.headers[IdempotencyKey.header], isNull);
      expect(
        adapter.requests.single.receiveTimeout,
        isNot(AppConstants.aiReceiveTimeout),
      );
    });

    test('can be cancelled', () async {
      final FakeAdapter adapter = FakeAdapter(
        (_) => const FakeReply(200, <String, Object>{}),
      );
      final ApiClient client = _client(adapter, SessionStore.memory());
      final CancelToken token = CancelToken()..cancel('user');
      await expectLater(
        client.postAi<Map<String, dynamic>>(
          '/x',
          idempotencyKey: IdempotencyKey.create(),
          cancelToken: token,
        ),
        throwsA(
          isA<ApiError>().having(
            (ApiError e) => e.kind,
            'kind',
            ApiErrorKind.cancelled,
          ),
        ),
      );
    });
  });

  group('IdempotencyKey', () {
    test('is a version 4 UUID and is unique', () {
      final RegExp uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final Set<String> seen = <String>{};
      for (int i = 0; i < 50; i++) {
        final String key = IdempotencyKey.create();
        expect(uuid.hasMatch(key), isTrue, reason: key);
        seen.add(key);
      }
      expect(seen.length, 50);
    });
  });
}
