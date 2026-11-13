import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/idempotency_key.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/ai/bloc/ask_cubit.dart';
import 'package:round_ai/features/ai/bloc/source_drawer_cubit.dart';
import 'package:round_ai/features/ai/bloc/summary_cubit.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/models/ask_reply.dart';
import 'package:round_ai/features/ai/models/summary_content.dart';
import 'package:round_ai/features/ai/repository/ai_repository_impl.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/patient/models/fact.dart';
import 'package:round_ai/shared/widgets/ai_state.dart';

import 'support/fake_adapter.dart';
import 'support/fake_ai_repository.dart';

Future<(AiRepositoryImpl, FakeAdapter)> _impl(
  FakeReply Function(RequestOptions) handler,
) async {
  final SessionStore session = SessionStore(MemoryTokenStore());
  await session.save('tok', persist: false);
  final FakeAdapter adapter = FakeAdapter(handler);
  final ApiClient client = ApiClient(session: session, dio: fakeDio(adapter));
  return (
    AiRepositoryImpl(client, clock: () => DateTime(2026, 11, 12, 23, 59)),
    adapter,
  );
}

Map<String, Object> _env(
  String id, {
  String created = '2026-11-12T09:00:00Z',
  Map<String, Object>? content,
}) => <String, Object>{
  'artifact_id': id,
  'operation': 'summarize_patient',
  'patient_id': 'p1',
  'context_revision': 2,
  'status': 'draft',
  'review_state': 'draft',
  'outdated': false,
  'created_at': created,
  'content': content ?? <String, Object>{'one_liner': 'x'},
};

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI state mapping', () {
    test('every envelope maps to one state', () {
      expect(AiState.fromEnvelope(null), AiState.notGenerated);
      expect(AiState.fromEnvelope(envelopeOf()), AiState.draftReady);
      expect(
        AiState.fromEnvelope(envelopeOf(status: 'partial')),
        AiState.partial,
      );
      expect(
        AiState.fromEnvelope(envelopeOf(review: 'reviewed')),
        AiState.reviewed,
      );
      // Outdated wins, even for a reviewed version.
      expect(
        AiState.fromEnvelope(envelopeOf(review: 'reviewed', outdated: true)),
        AiState.outdated,
      );
    });
  });

  group('SummaryContent', () {
    test('reads the one-liner, sections, missing info and conflicts', () {
      final SummaryContent c = SummaryContent.fromEnvelope(envelopeOf());
      expect(c.oneLiner!.text, startsWith('72F'));
      expect(c.oneLiner!.label, ClaimLabel.fromChart);
      expect(c.oneLiner!.factIds, <String>['f1', 'f2']);
      expect(c.sections.single.title, 'Hospital course');
      expect(c.sections.single.claims, hasLength(2));
      expect(c.sections.single.claims.last.label, ClaimLabel.aiInterpretation);
      expect(c.missingInformation, <String>["Today's exam"]);
      expect(c.conflicts.single.label, 'Weight');
      expect(c.truncated, isFalse);
      expect(c.hasPlaceholders, isFalse);
    });

    test('plain text is never labelled as chart', () {
      final SummaryContent c = SummaryContent.fromEnvelope(
        envelopeOf(
          content: <String, dynamic>{
            'one_liner': 'A plain sentence',
            'sections': <String, Object>{
              'plan': 'Continue diuresis',
              'events': <Object>['one', 'two'],
            },
          },
        ),
      );
      expect(c.oneLiner!.label, ClaimLabel.aiInterpretation);
      expect(c.sections.map((SummarySection s) => s.title), <String>[
        'Plan',
        'Events',
      ]);
      expect(c.sections.first.text, 'Continue diuresis');
      expect(c.sections.last.claims.map((Claim x) => x.text), <String>[
        'one',
        'two',
      ]);
      expect(c.sections.last.claims.first.label, ClaimLabel.aiInterpretation);
    });

    test('not entered placeholders are found by section', () {
      final SummaryContent c = SummaryContent.fromEnvelope(
        envelopeOf(
          content: summaryContent(
            sections: <Object>[
              <String, Object>{
                'key': 'exam',
                'title': 'Exam',
                'text': 'Exam: [physical exam not entered]',
              },
              <String, Object>{'key': 'plan', 'title': 'Plan', 'text': 'Fine'},
            ],
          ),
        ),
      );
      expect(c.placeholderSections, <String>['exam']);
      expect(c.hasPlaceholders, isTrue);
    });

    test('a truncation note counts, an empty one does not', () {
      bool truncated(Object? v) => SummaryContent.fromEnvelope(
        envelopeOf(content: summaryContent(truncated: v)),
      ).truncated;
      expect(truncated(true), isTrue);
      expect(truncated('older notes left out'), isTrue);
      expect(truncated(<String>['source 3']), isTrue);
      expect(truncated(false), isFalse);
      expect(truncated(null), isFalse);
      expect(truncated(<String>[]), isFalse);
    });

    test('withheld parts are counted from validation issues', () {
      final AiEnvelope e = envelopeOf(
        status: 'partial',
        content: summaryContent(
          issues: <Object>[
            'a number was not in the chart',
            <String, Object>{'message': 'unsupported claim', 'section': 'x'},
          ],
        ),
      );
      expect(e.validationIssues, hasLength(2));
      expect(e.isPartial, isTrue);
    });
  });

  group('AskReply', () {
    test('reads the three statuses', () {
      expect(
        AskReply.fromJson(<String, dynamic>{
          'status': 'refused',
          'content': <String, Object>{'message': 'No.'},
        }).status,
        AskStatus.refused,
      );
      expect(
        AskReply.fromJson(<String, dynamic>{
          'content': <String, Object>{'status': 'needs_topic'},
        }).status,
        AskStatus.needsTopic,
      );
      // `draft` is the envelope status, not an ask status.
      expect(
        AskReply.fromJson(<String, dynamic>{
          'status': 'draft',
          'content': <String, Object>{'status': 'ok'},
        }).status,
        AskStatus.ok,
      );
    });

    test('keeps chart claims, evidence and how the search ran', () {
      final AskReply r = AskReply.fromJson(<String, dynamic>{
        'status': 'partial',
        'content': <String, Object>{
          'status': 'ok',
          'claims': <Object>[
            <String, Object>{
              'text': 'Cr 1.7',
              'label': 'From chart',
              'fact_ids': <String>['f1'],
            },
          ],
          'evidence': <Object>[
            <String, Object>{'id': 'e1', 'pmid': '123', 'title': 'Study'},
          ],
          'retrieval': <String, Object>{
            'searched_at': '2026-11-12T00:00:00Z',
            'sources': <String>['PubMed'],
            'excluded_retracted': 2,
          },
          'validation_issues': <Object>['x'],
        },
      });
      expect(r.claims.single.factIds, <String>['f1']);
      expect(
        r.evidence.single.pubmedUri.toString(),
        'https://pubmed.ncbi.nlm.nih.gov/123/',
      );
      expect(r.retrieval!.excludedRetracted, 2);
      expect(r.partial, isTrue);
      expect(r.issueCount, 1);
    });
  });

  group('AiRepositoryImpl', () {
    test('takes the newest saved summary', () async {
      final (AiRepositoryImpl repo, FakeAdapter a) = await _impl(
        (_) => FakeReply(200, <String, Object>{
          'artifacts': <Object>[
            _env('old', created: '2026-11-10T09:00:00Z'),
            _env('new', created: '2026-11-12T09:00:00Z'),
          ],
        }),
      );
      final Result<AiEnvelope?> r = await repo.latestSummary('p1');
      expect((r as Ok<AiEnvelope?>).value!.artifactId, 'new');
      expect(a.requests.single.path, '/patients/p1/artifacts');
      expect(a.requests.single.queryParameters, <String, dynamic>{
        'operation': 'summarize_patient',
      });
    });

    test('no saved summary is null, not an error', () async {
      final (AiRepositoryImpl repo, _) = await _impl(
        (_) => const FakeReply(200, <Object>[]),
      );
      expect(
        ((await repo.latestSummary('p1')) as Ok<AiEnvelope?>).value,
        isNull,
      );
    });

    test('reads the full version when the list has only headers', () async {
      final (AiRepositoryImpl repo, FakeAdapter a) = await _impl(
        (RequestOptions o) => o.path == '/artifacts/a9'
            ? FakeReply(
                200,
                _env('a9', content: <String, Object>{'one_liner': 'full'}),
              )
            : FakeReply(200, <Object>[
                <String, Object>{'artifact_id': 'a9', 'status': 'draft'},
              ]),
      );
      final AiEnvelope e =
          ((await repo.latestSummary('p1')) as Ok<AiEnvelope?>).value!;
      expect(e.content['one_liner'], 'full');
      expect(a.requests.last.path, '/artifacts/a9');
    });

    test('generate sends the date and the idempotency key', () async {
      final (AiRepositoryImpl repo, FakeAdapter a) = await _impl(
        (_) => FakeReply(200, _env('a1')),
      );
      final Result<AiEnvelope> r = await repo.generateSummary(
        'p1',
        idempotencyKey: 'key-1',
      );
      expect(r, isA<Ok<AiEnvelope>>());
      final RequestOptions o = a.requests.single;
      expect(o.method, 'POST');
      expect(o.path, '/patients/p1/summary');
      expect(o.data, <String, String>{'date': '2026-11-12'});
      expect(o.headers[IdempotencyKey.header], 'key-1');
    });

    test('an envelope inside "artifact" is read', () async {
      final (AiRepositoryImpl repo, _) = await _impl(
        (_) => FakeReply(200, <String, Object>{'artifact': _env('wrapped')}),
      );
      final Result<AiEnvelope> r = await repo.generateSummary(
        'p1',
        idempotencyKey: 'k',
      );
      expect((r as Ok<AiEnvelope>).value.artifactId, 'wrapped');
    });

    test('errors keep their code for the screen', () async {
      final (AiRepositoryImpl repo, _) = await _impl(
        (_) => const FakeReply(409, <String, Object>{
          'error': <String, Object>{
            'code': 'no_reviewed_facts',
            'message': 'm',
          },
        }),
      );
      final Result<AiEnvelope> r = await repo.generateSummary(
        'p1',
        idempotencyKey: 'k',
      );
      expect(
        (r as Err<AiEnvelope>).failure.message,
        'Review chart facts first.',
      );
    });

    test(
      'review posts, then reads the saved version if the reply is bare',
      () async {
        final (AiRepositoryImpl repo, FakeAdapter a) = await _impl(
          (RequestOptions o) => o.method == 'POST'
              ? const FakeReply(200, <String, Object>{'ok': true})
              : FakeReply(200, <String, Object>{
                  ..._env('a1'),
                  'review_state': 'reviewed',
                }),
        );
        final Result<AiEnvelope> r = await repo.markReviewed('a1');
        expect((r as Ok<AiEnvelope>).value.isReviewed, isTrue);
        expect(a.requests.first.path, '/artifacts/a1/review');
        expect(a.requests.last.path, '/artifacts/a1');
      },
    );

    test('fact source and ask use the expected calls', () async {
      final (AiRepositoryImpl repo, FakeAdapter a) = await _impl(
        (RequestOptions o) => o.path.endsWith('/source')
            ? const FakeReply(200, <String, Object>{
                'passage': 'Cr 1.7',
                'source_title': 'Progress note',
                'source_time': '2026-11-12T08:00:00Z',
              })
            : const FakeReply(200, <String, Object>{
                'status': 'draft',
                'content': <String, Object>{'status': 'needs_topic'},
              }),
      );
      final Result<SourcePassage> s = await repo.factSource('f1');
      expect((s as Ok<SourcePassage>).value.sourceTitle, 'Progress note');
      expect(a.requests.last.path, '/facts/f1/source');

      final Result<AskReply> r = await repo.ask(
        'p1',
        question: 'Explain this',
        topic: ' AKI ',
        idempotencyKey: 'k2',
      );
      expect((r as Ok<AskReply>).value.status, AskStatus.needsTopic);
      expect(a.requests.last.path, '/patients/p1/ask');
      expect(a.requests.last.data, <String, String>{
        'question': 'Explain this',
        'topic': 'AKI',
      });
      expect(a.requests.last.headers[IdempotencyKey.header], 'k2');
    });
  });

  group('SummaryCubit', () {
    test('no saved summary is Not generated', () async {
      final FakeAiRepository repo = FakeAiRepository();
      final SummaryCubit cubit = SummaryCubit(repo, 'p1');
      await cubit.load();
      expect(cubit.state.phase, SummaryPhase.idle);
      expect(cubit.state.aiState, AiState.notGenerated);
      expect(cubit.state.canMarkReviewed, isFalse);
      await cubit.close();
    });

    test('a saved draft is loaded and can be reviewed', () async {
      final FakeAiRepository repo = FakeAiRepository()
        ..latest = Ok<AiEnvelope?>(envelopeOf());
      final SummaryCubit cubit = SummaryCubit(repo, 'p1');
      await cubit.load();
      expect(cubit.state.aiState, AiState.draftReady);
      expect(cubit.state.content!.oneLiner, isNotNull);
      expect(cubit.state.canMarkReviewed, isTrue);
      await cubit.close();
    });

    test('a failed load shows the error and is retried by load', () async {
      final FakeAiRepository repo = FakeAiRepository()
        ..latest = Err<AiEnvelope?>(FakeAiRepository.failure('network_error'));
      final SummaryCubit cubit = SummaryCubit(repo, 'p1');
      await cubit.load();
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.errorFromLoad, isTrue);
      expect(cubit.state.aiState, AiState.failed);
      repo.latest = Ok<AiEnvelope?>(envelopeOf());
      await cubit.load();
      expect(cubit.state.error, isNull);
      expect(cubit.state.hasSummary, isTrue);
      await cubit.close();
    });

    test('generate makes a draft and tells the screen to reload', () async {
      final FakeAiRepository repo = FakeAiRepository();
      final SummaryCubit cubit = SummaryCubit(repo, 'p1');
      await cubit.load();
      await cubit.generate();
      expect(cubit.state.aiState, AiState.draftReady);
      expect(cubit.state.changes, 1);
      expect(repo.generateKeys, hasLength(1));
      await cubit.close();
    });

    test('a retry after a failed generation reuses the key', () async {
      final FakeAiRepository repo = FakeAiRepository()
        ..generated = Err<AiEnvelope>(
          FakeAiRepository.failure('ai_unavailable'),
        );
      final SummaryCubit cubit = SummaryCubit(repo, 'p1');
      await cubit.generate();
      expect(cubit.state.error!.isRetryable, isTrue);
      expect(cubit.state.aiState, AiState.failed);
      repo.generated = Ok<AiEnvelope>(envelopeOf());
      await cubit.generate();
      expect(repo.generateKeys, hasLength(2));
      expect(repo.generateKeys.first, repo.generateKeys.last);
      expect(cubit.state.error, isNull);

      // The next tap, after a success, is a new action with a new key.
      await cubit.generate();
      expect(repo.generateKeys.last, isNot(repo.generateKeys.first));
      await cubit.close();
    });

    test('a failure that retry cannot fix does not keep the key', () async {
      final FakeAiRepository repo = FakeAiRepository()
        ..generated = Err<AiEnvelope>(
          FakeAiRepository.failure('no_reviewed_facts'),
        );
      final SummaryCubit cubit = SummaryCubit(repo, 'p1');
      await cubit.generate();
      expect(cubit.state.error!.kind.name, 'noReviewedFacts');
      await cubit.generate();
      expect(repo.generateKeys.first, isNot(repo.generateKeys.last));
      await cubit.close();
    });

    test('AI off and the daily limit show their own states', () async {
      final FakeAiRepository repo = FakeAiRepository()
        ..generated = Err<AiEnvelope>(FakeAiRepository.failure('ai_disabled'));
      final SummaryCubit cubit = SummaryCubit(repo, 'p1');
      await cubit.generate();
      expect(cubit.state.aiState, AiState.unavailable);
      expect(
        cubit.state.error!.userMessage,
        'AI is temporarily off. Manual entry still works.',
      );
      repo.generated = Err<AiEnvelope>(
        FakeAiRepository.failure('daily_limit', status: 429),
      );
      await cubit.generate();
      expect(cubit.state.error!.userMessage, 'Daily AI limit reached.');
      await cubit.close();
    });

    test('cancel stops it without an error', () async {
      final FakeAiRepository repo = FakeAiRepository();
      final Completer<Result<AiEnvelope>> never =
          Completer<Result<AiEnvelope>>();
      repo.onGenerate = (_) => never.future;
      final SummaryCubit cubit = SummaryCubit(repo, 'p1');
      final Future<void> run = cubit.generate();
      await _settle();
      expect(cubit.state.generating, isTrue);
      expect(cubit.state.aiState, AiState.loading);
      cubit.cancel();
      expect(repo.lastToken!.isCancelled, isTrue);
      never.complete(Err<AiEnvelope>(FakeAiRepository.failure('cancelled')));
      await run;
      expect(cubit.state.generating, isFalse);
      expect(cubit.state.error, isNull);
      await cubit.close();
    });

    test('an outdated summary stays readable and cannot be reviewed', () async {
      final FakeAiRepository repo = FakeAiRepository()
        ..latest = Ok<AiEnvelope?>(envelopeOf(outdated: true));
      final SummaryCubit cubit = SummaryCubit(repo, 'p1');
      await cubit.load();
      expect(cubit.state.aiState, AiState.outdated);
      expect(cubit.state.content!.oneLiner, isNotNull, reason: 'old text kept');
      expect(cubit.state.reviewBlockedReason, outdatedReviewMessage);
      await cubit.markReviewed();
      expect(repo.reviewed_, isEmpty, reason: 'blocked before any call');
      await cubit.close();
    });

    test(
      'regenerating keeps the old version on screen while it runs',
      () async {
        final FakeAiRepository repo = FakeAiRepository()
          ..latest = Ok<AiEnvelope?>(envelopeOf(outdated: true));
        final Completer<Result<AiEnvelope>> wait =
            Completer<Result<AiEnvelope>>();
        repo.onGenerate = (_) => wait.future;
        final SummaryCubit cubit = SummaryCubit(repo, 'p1');
        await cubit.load();
        final Future<void> run = cubit.generate();
        await _settle();
        expect(cubit.state.generating, isTrue);
        expect(cubit.state.content, isNotNull);
        wait.complete(Ok<AiEnvelope>(envelopeOf(id: 'a2')));
        await run;
        expect(cubit.state.outdated, isFalse);
        expect(cubit.state.envelope!.artifactId, 'a2');
        await cubit.close();
      },
    );

    test('missing text blocks review and marks the section', () async {
      final FakeAiRepository repo = FakeAiRepository()
        ..latest = Ok<AiEnvelope?>(
          envelopeOf(
            content: summaryContent(
              sections: <Object>[
                <String, Object>{
                  'key': 'exam',
                  'title': 'Exam',
                  'text': '[exam not entered]',
                },
              ],
            ),
          ),
        );
      final SummaryCubit cubit = SummaryCubit(repo, 'p1');
      await cubit.load();
      expect(cubit.state.reviewBlockedReason, placeholderReviewMessage);
      expect(cubit.state.markedSections, contains('exam'));
      await cubit.markReviewed();
      expect(repo.reviewed_, isEmpty);
      await cubit.close();
    });

    test('mark reviewed saves the version and flips the state', () async {
      final FakeAiRepository repo = FakeAiRepository()
        ..latest = Ok<AiEnvelope?>(envelopeOf());
      final SummaryCubit cubit = SummaryCubit(repo, 'p1');
      await cubit.load();
      await cubit.markReviewed();
      expect(repo.reviewed_, <String>['a1']);
      expect(cubit.state.aiState, AiState.reviewed);
      expect(cubit.state.canMarkReviewed, isFalse);
      expect(cubit.state.changes, 1);
      await cubit.close();
    });

    test('the server can still refuse, and names the sections', () async {
      final FakeAiRepository repo = FakeAiRepository()
        ..latest = Ok<AiEnvelope?>(envelopeOf())
        ..reviewed = Err<AiEnvelope>(
          FakeAiRepository.failure(
            'unresolved_flags',
            status: 409,
            details: <String, dynamic>{
              'sections': <String>['course'],
            },
          ),
        );
      final SummaryCubit cubit = SummaryCubit(repo, 'p1');
      await cubit.load();
      await cubit.markReviewed();
      expect(
        cubit.state.reviewError!.userMessage,
        'Some sections still have unresolved flags.',
      );
      expect(cubit.state.flaggedSections, <String>['course']);
      expect(cubit.state.markedSections, contains('course'));
      expect(cubit.state.aiState, AiState.draftReady);
      await cubit.close();
    });

    test('an outdated refusal reloads so Outdated shows', () async {
      final FakeAiRepository repo = FakeAiRepository()
        ..latest = Ok<AiEnvelope?>(envelopeOf())
        ..reviewed = Err<AiEnvelope>(
          FakeAiRepository.failure('outdated', status: 409),
        );
      final SummaryCubit cubit = SummaryCubit(repo, 'p1');
      await cubit.load();
      repo.latest = Ok<AiEnvelope?>(envelopeOf(outdated: true));
      await cubit.markReviewed();
      expect(cubit.state.aiState, AiState.outdated);
      expect(cubit.state.reviewError!.userMessage, outdatedReviewMessage);
      await cubit.close();
    });
  });

  group('AskCubit', () {
    test('an answer is added to the thread', () async {
      final FakeAiRepository repo = FakeAiRepository()
        ..asked = const Ok<AskReply>(
          AskReply(status: AskStatus.ok, message: 'Answer'),
        );
      final AskCubit cubit = AskCubit(repo, 'p1');
      await cubit.ask('What changed today?');
      expect(cubit.state.turns.single.status, TurnStatus.done);
      expect(cubit.state.turns.single.reply!.message, 'Answer');
      await cubit.close();
    });

    test('blank questions are not sent', () async {
      final FakeAiRepository repo = FakeAiRepository();
      final AskCubit cubit = AskCubit(repo, 'p1');
      await cubit.ask('   ');
      expect(repo.askKeys, isEmpty);
      await cubit.close();
    });

    test('only one question runs at a time', () async {
      final FakeAiRepository repo = FakeAiRepository();
      final Completer<Result<AskReply>> wait = Completer<Result<AskReply>>();
      repo.onAsk = (_, _) => wait.future;
      final AskCubit cubit = AskCubit(repo, 'p1');
      final Future<void> first = cubit.ask('one');
      await _settle();
      expect(cubit.state.busy, isTrue);
      await cubit.ask('two');
      expect(repo.askKeys, hasLength(1));
      wait.complete(const Ok<AskReply>(AskReply(status: AskStatus.ok)));
      await first;
      expect(cubit.state.busy, isFalse);
      await cubit.close();
    });

    test('retry reuses the key, a new question makes a new one', () async {
      final FakeAiRepository repo = FakeAiRepository()
        ..asked = Err<AskReply>(FakeAiRepository.failure('ai_unavailable'));
      final AskCubit cubit = AskCubit(repo, 'p1');
      await cubit.ask('Explain this problem');
      expect(cubit.state.turns.single.status, TurnStatus.failed);
      repo.asked = const Ok<AskReply>(AskReply(status: AskStatus.ok));
      await cubit.retry(cubit.state.turns.single.id);
      expect(repo.askKeys, hasLength(2));
      expect(repo.askKeys.first, repo.askKeys.last);
      expect(cubit.state.turns.single.status, TurnStatus.done);
      await cubit.ask('Another');
      expect(repo.askKeys.last, isNot(repo.askKeys.first));
      await cubit.close();
    });

    test(
      'a topic request is answered as a new question with the topic',
      () async {
        final FakeAiRepository repo = FakeAiRepository()
          ..asked = const Ok<AskReply>(AskReply(status: AskStatus.needsTopic));
        final AskCubit cubit = AskCubit(repo, 'p1');
        await cubit.ask('Find recent studies');
        expect(cubit.state.turns.single.reply!.status, AskStatus.needsTopic);
        repo.asked = const Ok<AskReply>(AskReply(status: AskStatus.ok));
        await cubit.answerTopic(
          cubit.state.turns.single.id,
          'AKI in heart failure',
        );
        expect(repo.askTopics.last, 'AKI in heart failure');
        expect(repo.askKeys.last, isNot(repo.askKeys.first));
        expect(cubit.state.turns, hasLength(2));
        expect(cubit.state.turns.last.question, 'Find recent studies');
        await cubit.close();
      },
    );

    test('an unsafe topic reads as a plain message', () async {
      final FakeAiRepository repo = FakeAiRepository()
        ..asked = Err<AskReply>(FakeAiRepository.failure('query_not_safe'));
      final AskCubit cubit = AskCubit(repo, 'p1');
      await cubit.ask('Find studies', topic: 'John Smith 1950');
      expect(
        cubit.state.turns.single.error!.userMessage,
        contains('patient identifiers'),
      );
      await cubit.close();
    });
  });

  group('SourceDrawerCubit', () {
    test('loads the source of each fact', () async {
      final FakeAiRepository repo = FakeAiRepository();
      final SourceDrawerCubit cubit = SourceDrawerCubit(repo, <String>[
        'f1',
        'f2',
      ]);
      await cubit.load();
      expect(repo.sourceRequests, <String>['f1', 'f2']);
      expect(
        cubit.state.entries.every(
          (SourceEntry e) => e.load == SourceLoad.ready,
        ),
        isTrue,
      );
      expect(cubit.state.entries.first.source!.passage, 'Cr 1.7 this morning');
      await cubit.close();
    });

    test('one failed source can be retried alone', () async {
      final FakeAiRepository repo = FakeAiRepository();
      repo.sources['f2'] = Err<SourcePassage>(
        FakeAiRepository.failure('access_denied', status: 403),
      );
      final SourceDrawerCubit cubit = SourceDrawerCubit(repo, <String>[
        'f1',
        'f2',
      ]);
      await cubit.load();
      expect(cubit.state.entries.first.load, SourceLoad.ready);
      expect(cubit.state.entries.last.load, SourceLoad.failed);
      repo.sources.remove('f2');
      await cubit.retry('f2');
      expect(cubit.state.entries.last.load, SourceLoad.ready);
      await cubit.close();
    });
  });

  group('census summary state', () {
    test('the pill and the AI state agree', () {
      expect(AiState.fromSummary(SummaryState.outdated), AiState.outdated);
      expect(AiState.fromSummary(SummaryState.draftReady), AiState.draftReady);
    });
  });
}
