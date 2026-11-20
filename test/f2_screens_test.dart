import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:dio/dio.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/ai/models/ai_envelope.dart';
import 'package:round_ai/features/census/bloc/census_bloc.dart';
import 'package:round_ai/features/census/bloc/census_event.dart';
import 'package:round_ai/features/census/models/census_intake.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';
import 'package:round_ai/features/census/screens/census_screen.dart';
import 'package:round_ai/features/census/widgets/add_patient_sheet.dart';
import 'package:round_ai/features/patient/models/chart_source.dart';
import 'package:round_ai/features/patient/models/fact.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/models/plan_structured.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';
import 'package:round_ai/features/patient/screens/add_source_screen.dart';
import 'package:round_ai/features/patient/screens/facts_review_screen.dart';
import 'package:round_ai/features/patient/screens/patient_overview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_ai_repository.dart';
import 'support/fake_notes_problems.dart';

PatientSummary _p(
  String id,
  String room,
  String state, {
  int facts = 0,
  int tasks = 0,
}) {
  return PatientSummary.fromJson(<String, Object>{
    'id': id,
    'team_id': 't1',
    'display_name': 'Pat $id',
    'room': room,
    'age_band': '70-79',
    'sex': 'F',
    'summary_state': state,
    'unreviewed_facts': facts,
    'open_tasks': tasks,
  });
}

FakeAiRepository _ai({AiEnvelope? latest}) =>
    FakeAiRepository()..latest = Ok<AiEnvelope?>(latest);

void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await InjectionContainer.instance.init(tokenStore: MemoryTokenStore());
  });

  group('census screen', () {
    testWidgets('lists patients by room with their summary state', (
      WidgetTester tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: CensusScreen(
            repository: _Census(<PatientSummary>[
              _p('a', '412B', 'Outdated', facts: 2, tasks: 1),
              _p('b', '101', 'Draft ready'),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('sort order, then room'),
        findsOneWidget,
      );
      expect(find.text('Outdated'), findsOneWidget);
      expect(find.text('Draft ready'), findsOneWidget);
      expect(find.text('2 facts to review · 1 task'), findsOneWidget);
      expect(find.text('No facts to review · No open tasks'), findsOneWidget);
      // The census is ordered by room: 101 above 412B.
      expect(
        tester.getTopLeft(find.text('Pat b')).dy,
        lessThan(tester.getTopLeft(find.text('Pat a')).dy),
      );
    });

    testWidgets('has no AI priority wording and no Discharge filter', (
      WidgetTester tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: CensusScreen(
            repository: _Census(<PatientSummary>[_p('a', '1', 'Reviewed')]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final String text in <String>[
        'Priority',
        'Discharge',
        'Highest first',
        'AI-assisted',
      ]) {
        expect(find.textContaining(text), findsNothing, reason: text);
      }
    });

    testWidgets('the filters work on chart data', (WidgetTester tester) async {
      _wide(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: CensusScreen(
            repository: _Census(<PatientSummary>[
              _p('a', '1', 'Outdated'),
              _p('b', '2', 'Reviewed', facts: 3),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unreviewed facts'));
      await tester.pumpAndSettle();
      expect(find.text('Pat b'), findsOneWidget);
      expect(find.text('Pat a'), findsNothing);
      await tester.tap(find.text('Outdated summary'));
      await tester.pumpAndSettle();
      expect(find.text('Pat a'), findsOneWidget);
      expect(find.text('Pat b'), findsNothing);
    });

    testWidgets('a failed load shows a retry that works', (
      WidgetTester tester,
    ) async {
      _wide(tester);
      final _Census repo = _Census(<PatientSummary>[_p('a', '1', 'Reviewed')])
        ..fail = true;
      await tester.pumpWidget(
        MaterialApp(home: CensusScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('The census could not be loaded.'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Pat a'), findsOneWidget);
    });

    testWidgets('the add sheet asks for every field and warns in dev', (
      WidgetTester tester,
    ) async {
      _wide(tester);
      final _Census repo = _Census(<PatientSummary>[]);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<CensusBloc>(
            create: (_) => CensusBloc(repo)..add(const CensusRequested()),
            child: const Scaffold(body: AddPatientSheet(teamId: 't1')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Development build: use fictional names only.'),
        AppEnvironment.type.isProduction ? findsNothing : findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add patient'));
      await tester.pumpAndSettle();
      expect(find.text('Fill in every field.'), findsOneWidget);
      expect(repo.added, 0);
    });
  });

  group('patient overview', () {
    testWidgets('shows what is missing and never fills it in', (
      WidgetTester tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: PatientOverviewScreen(
            patientId: 'p1',
            aiRepository: _ai(),
            problemsRepository: FakeProblemsRepository(),
            repository: _Patients(
              PatientDetail(
                patient: _p('p1', '5', 'Not generated', facts: 2),
                revision: 1,
                missingInformation: const <String>["Today's exam"],
              ),
              const PatientChanges(hasBaseline: false, items: <InsightItem>[]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Review a summary to set the baseline.'),
        findsOneWidget,
      );
      expect(find.text("Today's exam"), findsOneWidget);
      // Plan has no text, so it says so.
      expect(find.text("Today's plan"), findsWidgets);
      // One for the empty plan, one for the missing exam.
      expect(find.text('Not entered'), findsNWidgets(2));
      expect(find.textContaining('No summary yet'), findsOneWidget);
      // Not generated, so nothing is labelled as an AI draft.
      expect(find.text('AI draft · review required'), findsNothing);
      expect(find.text('Review chart facts (2 waiting)'), findsOneWidget);
      expect(find.textContaining('priority'), findsNothing);
      // Every section is connected now, so all are offered.
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Sign-out'), findsOneWidget);
    });

    testWidgets('a draft summary is labelled and shows its state', (
      WidgetTester tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: PatientOverviewScreen(
            patientId: 'p1',
            aiRepository: _ai(latest: envelopeOf()),
            problemsRepository: FakeProblemsRepository(),
            repository: _Patients(
              PatientDetail(
                patient: _p('p1', '5', 'Draft ready'),
                revision: 2,
                planToday: const <String>['Continue diuresis'],
              ),
              const PatientChanges(
                hasBaseline: true,
                items: <InsightItem>[InsightItem(label: '', text: 'Cr up')],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AI draft · review required'), findsOneWidget);
      expect(find.text('• Continue diuresis'), findsOneWidget);
      expect(find.text('• Cr up'), findsOneWidget);
    });

    testWidgets('a failed changes call does not blank the patient', (
      WidgetTester tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: PatientOverviewScreen(
            patientId: 'p1',
            aiRepository: _ai(),
            problemsRepository: FakeProblemsRepository(),
            repository: _Patients(
              PatientDetail(patient: _p('p1', '5', 'Reviewed'), revision: 1),
              null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pat p1'), findsOneWidget);
      expect(
        find.textContaining('Changes could not be loaded'),
        findsOneWidget,
      );
    });
  });

  group('chart data screens', () {
    testWidgets('fact review shows the passage and enables buttons on pick', (
      WidgetTester tester,
    ) async {
      _wide(tester);
      final _Chart chart = _Chart(<Fact>[
        const Fact(
          id: 'f1',
          name: 'Creatinine',
          value: '1.7',
          unit: 'mg/dL',
          status: FactStatus.pending,
          passage: 'Cr 1.7 this morning',
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: FactsReviewScreen(patientId: 'p1', repository: chart),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Only confirmed facts are used by AI'),
        findsOneWidget,
      );
      expect(find.text('1.7 mg/dL'), findsOneWidget);
      expect(find.text('“Cr 1.7 this morning”'), findsOneWidget);
      expect(find.text('Time unknown'), findsOneWidget);
      // Nothing is ticked yet, so the bulk buttons are off.
      expect(find.text('Confirm'), findsWidgets);
      expect(find.text('Confirm (1)'), findsNothing);

      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      expect(find.text('Confirm (1)'), findsOneWidget);
      await tester.tap(find.text('Confirm (1)'));
      await tester.pumpAndSettle();
      expect(chart.decisions, <String>['f1:true']);
      expect(
        find.text('All done. No facts are waiting for review.'),
        findsOneWidget,
      );
    });

    testWidgets('add source needs text, and shows the free-text hint', (
      WidgetTester tester,
    ) async {
      _wide(tester);
      final _Chart chart = _Chart(const <Fact>[]);
      await tester.pumpWidget(
        MaterialApp(
          home: AddSourceScreen(patientId: 'p1', repository: chart),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Do not enter names, MRNs or dates of birth.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('AI only uses them after you confirm'),
        findsOneWidget,
      );
      await tester.tap(find.text('Save and read facts'));
      await tester.pumpAndSettle();
      expect(find.text('Paste or type the chart text first.'), findsOneWidget);
      expect(chart.sourcesAdded, 0);
    });

    testWidgets('a failed read keeps the text and offers a retry', (
      WidgetTester tester,
    ) async {
      _wide(tester);
      final _Chart chart = _Chart(const <Fact>[])..extractFails = true;
      await tester.pumpWidget(
        MaterialApp(
          home: AddSourceScreen(patientId: 'p1', repository: chart),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Cr 1.7');
      await tester.tap(find.text('Save and read facts'));
      await tester.pumpAndSettle();
      expect(find.textContaining('The text is saved.'), findsOneWidget);
      expect(find.text('Try reading facts again'), findsOneWidget);
      expect(chart.sourcesAdded, 1);
    });
  });
}

class _Census implements CensusRepository {
  _Census(this.patients);

  List<PatientSummary> patients;
  bool fail = false;
  int added = 0;

  @override
  Future<Result<List<PatientSummary>>> loadPatients() async {
    if (fail) {
      return Err<List<PatientSummary>>(ApiFailure(const ApiError.network()));
    }
    final List<PatientSummary> sorted = List<PatientSummary>.of(patients)
      ..sort(PatientSummary.compareByRoom);
    return Ok<List<PatientSummary>>(sorted);
  }

  @override
  Future<Result<PatientSummary>> addPatient(NewPatient patient) async {
    added++;
    return Ok<PatientSummary>(_p('new', patient.room, 'Not generated'));
  }

  @override
  Future<Result<CensusIntakeProposal>> intakeCensus({
    required TempMedia media,
    required String idempotencyKey,
    String? teamId,
    CancelToken? cancelToken,
  }) async =>
      Err<CensusIntakeProposal>(ApiFailure(const ApiError.network()));

  @override
  Future<Result<CensusConfirmResult>> confirmCensus(
    String intakeId, {
    required List<ProposedCensusPatient> items,
  }) async =>
      Err<CensusConfirmResult>(ApiFailure(const ApiError.network()));

  @override
  Future<Result<CensusExport>> exportCensus({String? teamId}) async =>
      const Ok<CensusExport>(CensusExport(text: ''));

  @override
  Future<Result<void>> setSortOrder(String patientId, int sortOrder) async =>
      const Ok<void>(null);
}

class _Patients implements PatientRepository {
  _Patients(this.detail, this.changes);

  final PatientDetail detail;
  final PatientChanges? changes;

  @override
  Future<Result<PatientDetail>> loadDetail(String patientId) async =>
      Ok<PatientDetail>(detail);

  @override
  Future<Result<PatientChanges>> loadChanges(String patientId) async {
    final PatientChanges? c = changes;
    if (c == null) {
      return Err<PatientChanges>(ApiFailure(const ApiError.network()));
    }
    return Ok<PatientChanges>(c);
  }

  @override
  Future<Result<void>> savePlan(String patientId, List<String> lines) async =>
      const Ok<void>(null);

  @override
  Future<Result<void>> saveStructuredPlan(
    String patientId,
    PlanStructured plan,
  ) async =>
      const Ok<void>(null);
}

class _Chart implements ChartDataRepository {
  _Chart(List<Fact> facts) : _facts = List<Fact>.of(facts);

  final List<Fact> _facts;
  final List<String> decisions = <String>[];
  int sourcesAdded = 0;
  bool extractFails = false;

  @override
  Future<Result<ChartSource>> addSource(
    String patientId, {
    required ChartSourceKind kind,
    required DateTime time,
    required String text,
  }) async {
    sourcesAdded++;
    return Ok<ChartSource>(ChartSource(id: 's1', kind: kind));
  }

  @override
  Future<Result<List<ChartSource>>> listSources(String patientId) async =>
      const Ok<List<ChartSource>>(<ChartSource>[]);

  @override
  Future<Result<void>> extract(String patientId, String sourceId) async {
    if (extractFails) {
      return Err<void>(ApiFailure(const ApiError.network()));
    }
    return const Ok<void>(null);
  }

  @override
  Future<Result<List<Fact>>> pendingFacts(String patientId) async =>
      Ok<List<Fact>>(List<Fact>.of(_facts));

  @override
  Future<Result<void>> decide(
    String patientId,
    List<String> factIds, {
    required bool confirm,
  }) async {
    for (final String factId in factIds) {
      decisions.add('$factId:$confirm');
    }
    final Set<String> ids = factIds.toSet();
    _facts.removeWhere((Fact f) => ids.contains(f.id));
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> addFact(String patientId, NewFact fact) async =>
      const Ok<void>(null);
}
