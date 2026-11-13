import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/patient/models/problem.dart';
import 'package:round_ai/features/problems/models/coding_suggestion.dart';
import 'package:round_ai/features/problems/repository/problems_repository_impl.dart';

import 'support/fake_adapter.dart';
import 'support/fake_notes_problems.dart';

Future<ApiClient> _client(FakeAdapter adapter) async {
  final SessionStore session = SessionStore(MemoryTokenStore());
  await session.save('tok', persist: false);
  return ApiClient(session: session, dio: fakeDio(adapter));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('coding models', () {
    test('parses suggestions, empty candidates and uncertain flag', () {
      final CodingSuggestResult r = CodingSuggestResult.fromEnvelope(
        artifactId: 'a1',
        content: <String, dynamic>{
          'label': codingReviewLabel,
          'problems': <Object>[
            <String, Object>{
              'problem_id': 'pr1',
              'problem_label': 'AKI',
              'uncertain': true,
              'candidates': <Object>[],
              'suggestions': <Object>[],
              'reviewer_notes': <String>['No codes matched'],
            },
            <String, Object>{
              'problem_id': 'pr2',
              'problem_label': 'HF',
              'uncertain': false,
              'suggestions': <Object>[
                <String, Object>{
                  'code': 'i50.9',
                  'description': 'Heart failure, unspecified',
                  'fact_ids': <String>['f1'],
                  'missing_for_specificity': <String>['EF'],
                  'coding_status': 'suggested',
                  'rationale': 'Matches label',
                },
              ],
            },
          ],
        },
      );
      expect(r.problems.first.hasNoCandidates, isTrue);
      expect(r.problems.first.uncertain, isTrue);
      final IcdCodeSuggestion s = r.problems[1].suggestions.single;
      expect(s.code, 'I50.9');
      expect(s.factIds, <String>['f1']);
      expect(s.missingForSpecificity, <String>['EF']);
      expect(s.uncertainNotConfirmed, isFalse);
    });

    test('Problem parses accepted code_suggestion', () {
      final Problem p = Problem.fromJson(<String, dynamic>{
        'id': 'p1',
        'label': 'AKI',
        'state': 'confirmed',
        'code_suggestion': <String, Object>{
          'code': 'N17.9',
          'description': 'Acute kidney failure, unspecified',
          'label': codingReviewLabel,
        },
      });
      expect(p.state.canSuggestCodes, isTrue);
      expect(p.codeSuggestion?.code, 'N17.9');
      expect(p.codeSuggestion?.label, codingReviewLabel);
    });
  });

  group('ProblemsRepositoryImpl coding', () {
    test('suggestCoding posts problem_id and reads envelope', () async {
      final FakeAdapter a = FakeAdapter(
        (RequestOptions o) => FakeReply(200, <String, Object>{
          'artifact_id': 'art1',
          'operation': 'suggest_icd',
          'patient_id': 'p1',
          'context_revision': 1,
          'status': 'draft',
          'review_state': 'draft',
          'outdated': false,
          'created_at': '2026-11-13T00:00:00Z',
          'content': <String, Object>{
            'label': codingReviewLabel,
            'problems': <Object>[
              <String, Object>{
                'problem_id': 'pr1',
                'problem_label': 'AKI',
                'suggestions': <Object>[
                  <String, Object>{
                    'code': 'N17.9',
                    'description': 'AKI unspecified',
                    'coding_status': 'suggested',
                  },
                ],
              },
            ],
          },
        }),
      );
      final ProblemsRepositoryImpl repo = ProblemsRepositoryImpl(
        await _client(a),
      );
      final Result<CodingSuggestResult> r = await repo.suggestCoding(
        'p1',
        problemId: 'pr1',
        idempotencyKey: 'k-icd',
      );
      final CodingSuggestResult value = (r as Ok<CodingSuggestResult>).value;
      expect(value.artifactId, 'art1');
      expect(value.problems.single.suggestions.single.code, 'N17.9');
      expect(a.requests.single.path, '/patients/p1/coding/suggest');
      expect(a.requests.single.data, <String, String>{'problem_id': 'pr1'});
      expect(a.requests.single.headers[IdempotencyKey.header], 'k-icd');
    });

    test('suggestCoding maps no_problems', () async {
      final FakeAdapter a = FakeAdapter(
        (RequestOptions o) => FakeReply(422, <String, Object>{
          'error': <String, Object>{
            'code': 'no_problems',
            'message': 'server text',
          },
        }),
      );
      final Result<CodingSuggestResult> r = await ProblemsRepositoryImpl(
        await _client(a),
      ).suggestCoding('p1', problemId: 'pr1', idempotencyKey: 'k');
      final ApiError error = (r as Err<CodingSuggestResult>).failure.apiError;
      expect(error.kind, ApiErrorKind.needsProblem);
      expect(error.userMessage, isNot(contains('server text')));
    });

    test('acceptCoding posts code and artifact_id', () async {
      final FakeAdapter a = FakeAdapter(
        (RequestOptions o) => FakeReply(200, <String, Object>{
          'problem_id': 'pr1',
          'code_suggestion': <String, Object>{
            'code': 'N17.9',
            'description': 'AKI unspecified',
            'label': codingReviewLabel,
          },
        }),
      );
      final Result<AcceptedCodeSuggestion> r = await ProblemsRepositoryImpl(
        await _client(a),
      ).acceptCoding('p1', 'pr1', code: 'N17.9', artifactId: 'art1');
      expect((r as Ok<AcceptedCodeSuggestion>).value.code, 'N17.9');
      expect(a.requests.single.path, '/patients/p1/problems/pr1/coding/accept');
      expect(a.requests.single.data, <String, String>{
        'code': 'N17.9',
        'artifact_id': 'art1',
      });
    });
  });

  group('FakeProblemsRepository accept flow', () {
    test('accept updates saved problem code', () async {
      final FakeProblemsRepository repo = FakeProblemsRepository(
        list: <Problem>[
          problem('pr1', 'AKI', state: ProblemState.confirmed),
        ],
      );
      repo.codingSuggest = Ok<CodingSuggestResult>(
        CodingSuggestResult(
          artifactId: 'a1',
          problems: <CodingProblemBlock>[
            CodingProblemBlock(
              problemId: 'pr1',
              problemLabel: 'AKI',
              suggestions: const <IcdCodeSuggestion>[
                IcdCodeSuggestion(
                  code: 'N17.9',
                  description: 'AKI unspecified',
                ),
              ],
            ),
          ],
        ),
      );
      final Result<CodingSuggestResult> suggested = await repo.suggestCoding(
        'p1',
        problemId: 'pr1',
        idempotencyKey: 'k',
      );
      expect(suggested, isA<Ok<CodingSuggestResult>>());
      final Result<AcceptedCodeSuggestion> accepted = await repo.acceptCoding(
        'p1',
        'pr1',
        code: 'N17.9',
        artifactId: 'a1',
      );
      expect((accepted as Ok<AcceptedCodeSuggestion>).value.code, 'N17.9');
      expect(repo.saved.single.codeSuggestion?.code, 'N17.9');
    });
  });
}
