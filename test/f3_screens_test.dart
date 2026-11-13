import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/ai/models/ask_reply.dart';
import 'package:round_ai/features/ai/widgets/ask_sheet.dart';
import 'package:round_ai/features/ai/widgets/evidence_card_view.dart';
import 'package:round_ai/features/ai/widgets/summary_card.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/patient/models/evidence_card.dart';
import 'package:round_ai/features/patient/models/fact.dart';

import 'support/fake_ai_repository.dart';

void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpCard(
  WidgetTester tester,
  FakeAiRepository repo, {
  bool aiOff = false,
  int revision = 1,
  VoidCallback? onChanged,
}) async {
  _wide(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SummaryCard(
            patientId: 'p1',
            revision: revision,
            aiOff: aiOff,
            repository: repo,
            onChanged: onChanged ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// onPressed of the button that holds [label]. Icon buttons are subclasses,
/// so they are found by their base type.
VoidCallback? _onPressed(WidgetTester tester, String label) {
  return tester
      .widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (Widget w) => w is ButtonStyleButton,
          ),
        ),
      )
      .onPressed;
}

final PatientSummary _patient = PatientSummary.fromJson(<String, Object>{
  'id': 'p1',
  'display_name': 'Pat One',
  'room': '5',
});

Future<void> _pumpAsk(
  WidgetTester tester,
  FakeAiRepository repo, {
  bool aiOff = false,
  List<String> topics = const <String>[],
}) async {
  _wide(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AskSheet(
          repository: repo,
          patient: _patient,
          aiOff: aiOff,
          topics: topics,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('summary card', () {
    testWidgets('nothing generated yet offers Generate', (
      WidgetTester tester,
    ) async {
      await _pumpCard(tester, FakeAiRepository());
      expect(find.text('Not generated'), findsOneWidget);
      expect(find.textContaining('No summary yet'), findsOneWidget);
      expect(find.text('Generate summary'), findsOneWidget);
      expect(find.text('AI draft · review required'), findsNothing);
      expect(find.text('Mark reviewed'), findsNothing);
    });

    testWidgets('a draft is labelled, shows its chip and its claims', (
      WidgetTester tester,
    ) async {
      await _pumpCard(
        tester,
        FakeAiRepository()..latest = Ok<AiEnvelope?>(envelopeOf()),
      );
      expect(find.text('AI draft · review required'), findsOneWidget);
      expect(find.text('Draft ready'), findsOneWidget);
      expect(find.textContaining('72F with CHF'), findsOneWidget);
      expect(find.text('Hospital course'), findsOneWidget);
      expect(find.text('From chart'), findsNWidgets(2));
      expect(find.text('AI interpretation'), findsOneWidget);
      // Missing information is shown as Not entered, and conflicts too.
      expect(find.text("Today's exam · Not entered"), findsOneWidget);
      expect(find.textContaining('Weight: Two values differ'), findsOneWidget);
      expect(_onPressed(tester, 'Mark reviewed'), isNotNull);
    });

    testWidgets('tapping a chart claim opens its source', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..latest = Ok<AiEnvelope?>(envelopeOf());
      await _pumpCard(tester, repo);
      await tester.tap(find.textContaining('Creatinine rose'));
      await tester.pumpAndSettle();
      expect(find.text('Source'), findsOneWidget);
      expect(repo.sourceRequests, <String>['f1']);
      expect(find.text('“Cr 1.7 this morning”'), findsOneWidget);
      expect(find.textContaining('Progress note'), findsOneWidget);
    });

    testWidgets('an interpretation says it has no chart source', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..latest = Ok<AiEnvelope?>(envelopeOf());
      await _pumpCard(tester, repo);
      await tester.tap(find.text('Likely cardiorenal.'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not a chart fact'), findsOneWidget);
      expect(repo.sourceRequests, isEmpty);
    });

    testWidgets('a chart claim with no source says so', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..latest = Ok<AiEnvelope?>(
          envelopeOf(
            content: <String, dynamic>{
              'one_liner': <String, Object>{
                'text': 'Claims chart without ids',
                'label': 'From chart',
              },
            },
          ),
        );
      await _pumpCard(tester, repo);
      await tester.tap(find.textContaining('Claims chart without ids'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No source is attached'), findsOneWidget);
    });

    testWidgets('a source that fails to load offers a retry', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..latest = Ok<AiEnvelope?>(envelopeOf());
      repo.sources['f1'] = Err<SourcePassage>(
        FakeAiRepository.failure('access_denied', status: 403),
      );
      await _pumpCard(tester, repo);
      await tester.tap(find.textContaining('Creatinine rose'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be loaded'), findsOneWidget);
      repo.sources.remove('f1');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('“Cr 1.7 this morning”'), findsOneWidget);
    });

    testWidgets('outdated: old text, a badge, Regenerate, no review', (
      WidgetTester tester,
    ) async {
      await _pumpCard(
        tester,
        FakeAiRepository()
          ..latest = Ok<AiEnvelope?>(envelopeOf(outdated: true)),
      );
      expect(find.text('Outdated'), findsOneWidget);
      expect(find.textContaining('The chart changed after'), findsOneWidget);
      expect(find.textContaining('72F with CHF'), findsOneWidget);
      expect(find.text('Regenerate'), findsOneWidget);
      expect(_onPressed(tester, 'Mark reviewed'), isNull);
      expect(
        find.text('Chart changed. Regenerate before marking reviewed.'),
        findsOneWidget,
      );
    });

    testWidgets('not entered text is highlighted and blocks review', (
      WidgetTester tester,
    ) async {
      await _pumpCard(
        tester,
        FakeAiRepository()
          ..latest = Ok<AiEnvelope?>(
            envelopeOf(
              content: summaryContent(
                sections: <Object>[
                  <String, Object>{
                    'key': 'exam',
                    'title': 'Exam',
                    'text': 'Exam: [physical exam not entered]',
                  },
                ],
              ),
            ),
          ),
      );
      expect(
        find.textContaining('[physical exam not entered]', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Needs attention before this can be reviewed.'),
        findsOneWidget,
      );
      expect(_onPressed(tester, 'Mark reviewed'), isNull);
      expect(find.textContaining('not entered. Add it'), findsOneWidget);
    });

    testWidgets('partial and truncated results say what happened', (
      WidgetTester tester,
    ) async {
      await _pumpCard(
        tester,
        FakeAiRepository()
          ..latest = Ok<AiEnvelope?>(
            envelopeOf(
              status: 'partial',
              content: summaryContent(
                truncated: true,
                issues: <Object>['a', 'b'],
              ),
            ),
          ),
      );
      expect(find.text('Partial result'), findsOneWidget);
      expect(find.textContaining('2 parts were withheld'), findsOneWidget);
      expect(find.textContaining('part of it was left out'), findsOneWidget);
    });

    testWidgets('generate shows progress with Cancel, then the draft', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository();
      final Completer<Result<AiEnvelope>> wait =
          Completer<Result<AiEnvelope>>();
      repo.onGenerate = (_) => wait.future;
      int changed = 0;
      await _pumpCard(tester, repo, onChanged: () => changed++);
      await tester.tap(find.text('Generate summary'));
      await tester.pump();
      expect(find.textContaining('up to a minute'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      wait.complete(Ok<AiEnvelope>(envelopeOf()));
      await tester.pumpAndSettle();
      expect(find.text('AI draft · review required'), findsOneWidget);
      expect(changed, 1, reason: 'the overview is told to reload');
    });

    testWidgets('Cancel stops a generation without an error', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository();
      final Completer<Result<AiEnvelope>> wait =
          Completer<Result<AiEnvelope>>();
      repo.onGenerate = (_) => wait.future;
      await _pumpCard(tester, repo);
      await tester.tap(find.text('Generate summary'));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      wait.complete(Err<AiEnvelope>(FakeAiRepository.failure('cancelled')));
      await tester.pumpAndSettle();
      expect(repo.lastToken!.isCancelled, isTrue);
      expect(find.text('Generate summary'), findsOneWidget);
      expect(find.text('Failed'), findsNothing);
    });

    testWidgets('no reviewed facts offers the way to review them', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..generated = Err<AiEnvelope>(
          FakeAiRepository.failure('no_reviewed_facts', status: 409),
        );
      await _pumpCard(tester, repo);
      await tester.tap(find.text('Generate summary'));
      await tester.pumpAndSettle();
      expect(find.text('Review chart facts first.'), findsOneWidget);
      expect(find.text('Review chart facts first'), findsOneWidget);
    });

    testWidgets('a failed generation says so and Retry works', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..generated = Err<AiEnvelope>(
          FakeAiRepository.failure('ai_invalid_output', status: 502),
        );
      await _pumpCard(tester, repo);
      await tester.tap(find.text('Generate summary'));
      await tester.pumpAndSettle();
      expect(
        find.text('Generation failed. Your data is unchanged.'),
        findsOneWidget,
      );
      repo.generated = Ok<AiEnvelope>(envelopeOf());
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('AI draft · review required'), findsOneWidget);
      expect(repo.generateKeys.first, repo.generateKeys.last);
    });

    testWidgets('AI off disables Generate and says why', (
      WidgetTester tester,
    ) async {
      await _pumpCard(tester, FakeAiRepository(), aiOff: true);
      expect(find.text(aiOffMessage), findsOneWidget);
      expect(_onPressed(tester, 'Generate summary'), isNull);
    });

    testWidgets('mark reviewed turns the card to Reviewed', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..latest = Ok<AiEnvelope?>(envelopeOf());
      await _pumpCard(tester, repo);
      await tester.tap(find.text('Mark reviewed'));
      await tester.pumpAndSettle();
      expect(repo.reviewed_, <String>['a1']);
      expect(find.text('Reviewed'), findsOneWidget);
      expect(find.text('AI draft · review required'), findsNothing);
      expect(find.text('Mark reviewed'), findsNothing);
    });

    testWidgets('a refusal by the server marks the named sections', (
      WidgetTester tester,
    ) async {
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
      await _pumpCard(tester, repo);
      await tester.tap(find.text('Mark reviewed'));
      await tester.pumpAndSettle();
      expect(
        find.text('Some sections still have unresolved flags.'),
        findsOneWidget,
      );
      expect(find.text('1 section is marked below.'), findsOneWidget);
      expect(
        find.textContaining('Needs attention before this can be reviewed.'),
        findsOneWidget,
      );
    });

    testWidgets('a new chart revision reads the summary again', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..latest = Ok<AiEnvelope?>(envelopeOf());
      await _pumpCard(tester, repo);
      expect(find.text('Draft ready'), findsOneWidget);
      repo.latest = Ok<AiEnvelope?>(envelopeOf(outdated: true));
      await _pumpCard(tester, repo, revision: 2);
      expect(find.text('Outdated'), findsOneWidget);
    });
  });

  group('ask sheet', () {
    testWidgets('keeps the seven suggested prompts and the identifiers hint', (
      WidgetTester tester,
    ) async {
      await _pumpAsk(tester, FakeAiRepository());
      for (final String p in askSuggestions) {
        expect(find.text(p), findsOneWidget);
      }
      expect(askSuggestions, hasLength(7));
      expect(
        find.text('Do not enter names, MRNs or dates of birth.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('this patient and this team only'),
        findsOneWidget,
      );
    });

    testWidgets('an answer shows chart claims with sources', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..asked = const Ok<AskReply>(
          AskReply(
            status: AskStatus.ok,
            claims: <Claim>[
              Claim(
                text: 'Creatinine is 1.7.',
                label: ClaimLabel.fromChart,
                factIds: <String>['f1'],
              ),
            ],
          ),
        );
      await _pumpAsk(tester, repo);
      await tester.tap(find.text('What changed today?'));
      await tester.pumpAndSettle();
      expect(find.text('AI draft · review required'), findsOneWidget);
      expect(find.text('Creatinine is 1.7.'), findsOneWidget);
      await tester.tap(find.text('Creatinine is 1.7.'));
      await tester.pumpAndSettle();
      expect(repo.sourceRequests, <String>['f1']);
      expect(find.text('“Cr 1.7 this morning”'), findsOneWidget);
    });

    testWidgets('a refusal shows its message and no AI draft label', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..asked = const Ok<AskReply>(
          AskReply(status: AskStatus.refused, message: 'Not for this patient.'),
        );
      await _pumpAsk(tester, repo);
      await tester.tap(find.text('Explain this problem'));
      await tester.pumpAndSettle();
      expect(find.text('Refused'), findsOneWidget);
      expect(find.text('Not for this patient.'), findsOneWidget);
      expect(find.text('AI draft · review required'), findsNothing);
    });

    testWidgets('needs a topic: pick a confirmed problem to go on', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..asked = const Ok<AskReply>(AskReply(status: AskStatus.needsTopic));
      await _pumpAsk(
        tester,
        repo,
        topics: const <String>['Acute kidney injury'],
      );
      await tester.tap(find.text('Find recent studies'));
      await tester.pumpAndSettle();
      expect(find.text('Topic'), findsOneWidget);
      repo.asked = const Ok<AskReply>(
        AskReply(status: AskStatus.ok, message: 'Done'),
      );
      await tester.tap(find.widgetWithText(ActionChip, 'Acute kidney injury'));
      await tester.pumpAndSettle();
      expect(repo.askTopics.last, 'Acute kidney injury');
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('needs a topic: a typed topic is sent', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..asked = const Ok<AskReply>(AskReply(status: AskStatus.needsTopic));
      await _pumpAsk(tester, repo);
      await tester.tap(find.text('Find recent studies'));
      await tester.pumpAndSettle();
      repo.asked = const Ok<AskReply>(
        AskReply(status: AskStatus.ok, message: 'Done'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Topic'),
        'SGLT2 in HFpEF',
      );
      await tester.tap(find.text('Ask with this topic'));
      await tester.pumpAndSettle();
      expect(repo.askTopics.last, 'SGLT2 in HFpEF');
    });

    testWidgets('evidence cards show every field and the search details', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..asked = Ok<AskReply>(
          AskReply(
            status: AskStatus.ok,
            evidence: <EvidenceCard>[
              EvidenceCard(
                id: 'e1',
                title: 'SGLT2 inhibitors in HFpEF',
                journal: 'NEJM',
                studyType: 'Randomized trial',
                accessLevel: 'Abstract only',
                publicationDate: DateTime.utc(2025, 3, 4),
                pmid: '12345',
                applicability: const Applicability(
                  resembles: <String>['Age band'],
                  unknown: <String>['Renal function'],
                ),
              ),
            ],
            retrieval: EvidenceRetrieval(
              searchedAt: DateTime.utc(2026, 11, 12),
              sources: const <String>['PubMed'],
              filters: const <String>['Last 5 years'],
              excludedRetracted: 2,
            ),
          ),
        );
      await _pumpAsk(tester, repo);
      await tester.tap(find.text('Find recent studies'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Retracted papers excluded: 2'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('SGLT2 inhibitors in HFpEF'), findsOneWidget);
      expect(find.textContaining('Randomized trial'), findsOneWidget);
      expect(find.textContaining('NEJM'), findsOneWidget);
      expect(find.text('Abstract only'), findsOneWidget);
      expect(find.text('PMID 12345'), findsOneWidget);
      expect(find.text('Resembles: Age band'), findsOneWidget);
      expect(find.text('Differs: Not entered'), findsOneWidget);
      expect(find.text('Unknown: Renal function'), findsOneWidget);
      expect(find.textContaining('Sources: PubMed'), findsOneWidget);
      expect(find.textContaining('Filters: Last 5 years'), findsOneWidget);
    });

    testWidgets('no studies says so, never a study from memory', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..asked = const Ok<AskReply>(
          AskReply(
            status: AskStatus.ok,
            retrieval: EvidenceRetrieval(sources: <String>['PubMed']),
          ),
        );
      await _pumpAsk(tester, repo);
      await tester.tap(find.text('Find recent studies'));
      await tester.pumpAndSettle();
      expect(find.text(noEvidenceMessage), findsOneWidget);
      expect(find.byType(EvidenceCardView), findsNothing);
    });

    testWidgets('the PMID link opens outside the app', (
      WidgetTester tester,
    ) async {
      Uri? opened;
      _wide(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceCardView(
              card: const EvidenceCard(
                id: 'e1',
                title: 'T',
                journal: 'J',
                studyType: 'Cohort',
                accessLevel: 'Source not available',
                pmid: '999',
              ),
              onOpen: (Uri uri) async {
                opened = uri;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('PMID 999'));
      expect(opened.toString(), 'https://pubmed.ncbi.nlm.nih.gov/999/');
      expect(find.text('Source not available'), findsOneWidget);
    });

    testWidgets('errors read plainly and Retry works', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository()
        ..asked = Err<AskReply>(
          FakeAiRepository.failure('evidence_retrieval_failed', status: 502),
        );
      await _pumpAsk(tester, repo);
      await tester.tap(find.text('Find recent studies'));
      await tester.pumpAndSettle();
      expect(find.text('Evidence search failed.'), findsOneWidget);
      repo.asked = const Ok<AskReply>(
        AskReply(status: AskStatus.ok, message: 'Fine'),
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Fine'), findsOneWidget);
      expect(repo.askKeys.first, repo.askKeys.last);
    });

    testWidgets('while a question runs the others are off, and Cancel works', (
      WidgetTester tester,
    ) async {
      final FakeAiRepository repo = FakeAiRepository();
      final Completer<Result<AskReply>> wait = Completer<Result<AskReply>>();
      repo.onAsk = (_, _) => wait.future;
      await _pumpAsk(tester, repo);
      await tester.tap(find.text('What changed today?'));
      await tester.pump();
      expect(find.textContaining('up to a minute'), findsOneWidget);
      expect(
        tester
            .widget<ActionChip>(
              find.widgetWithText(ActionChip, 'Create three questions'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancel'));
      expect(repo.lastToken!.isCancelled, isTrue);
      wait.complete(Err<AskReply>(FakeAiRepository.failure('cancelled')));
      await tester.pumpAndSettle();
      expect(find.text('Cancelled.'), findsOneWidget);
    });

    testWidgets('AI off turns asking off', (WidgetTester tester) async {
      final FakeAiRepository repo = FakeAiRepository();
      await _pumpAsk(tester, repo, aiOff: true);
      expect(
        find.text('AI is temporarily off. Manual entry still works.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ActionChip>(
              find.widgetWithText(ActionChip, 'What changed today?'),
            )
            .onPressed,
        isNull,
      );
      expect(repo.askKeys, isEmpty);
    });
  });
}
