import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/media/temp_media.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/census/bloc/census_bloc.dart';
import 'package:round_ai/features/census/bloc/census_event.dart';
import 'package:round_ai/features/census/bloc/census_state.dart';
import 'package:round_ai/features/census/models/census_intake.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/census/repository/census_repository.dart';
import 'package:round_ai/features/census/repository/census_repository_impl.dart';
import 'package:round_ai/features/patient/bloc/add_source_cubit.dart';
import 'package:round_ai/features/patient/bloc/facts_review_bloc.dart';
import 'package:round_ai/features/patient/bloc/patient_overview_bloc.dart';
import 'package:round_ai/features/patient/models/chart_source.dart';
import 'package:round_ai/features/patient/models/fact.dart';
import 'package:round_ai/features/patient/models/patient_detail.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository.dart';
import 'package:round_ai/features/patient/repository/chart_data_repository_impl.dart';
import 'package:round_ai/features/patient/repository/patient_repository.dart';
import 'package:round_ai/features/patient/repository/patient_repository_impl.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/repository/home_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_adapter.dart';

Map<String, Object> _patient(
  String id,
  String room, {
  String team = 't1',
  String state = 'Not generated',
  int facts = 0,
  int tasks = 0,
}) {
  return <String, Object>{
    'id': id,
    'team_id': team,
    'display_name': 'Pat $id',
    'room': room,
    'age_band': '70-79',
    'sex': 'F',
    'summary_state': state,
    'unreviewed_facts': facts,
    'open_tasks': tasks,
  };
}

PatientSummary _summary(String id, String room, {int facts = 0}) {
  return PatientSummary.fromJson(_patient(id, room, facts: facts));
}

class _Rig {
  _Rig(this.adapter, this.client, this.storage);

  final FakeAdapter adapter;
  final ApiClient client;
  final AppStorage storage;

  RequestOptions get last => adapter.requests.last;
}

Future<_Rig> _rig(
  FakeReply Function(RequestOptions) handler, {
  String? team = 't1',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'selected_team_id': ?team,
  });
  final SessionStore session = SessionStore(MemoryTokenStore());
  await session.save('tok', persist: false);
  final FakeAdapter adapter = FakeAdapter(handler);
  return _Rig(
    adapter,
    ApiClient(session: session, dio: fakeDio(adapter)),
    AppStorage(await SharedPreferences.getInstance(), session: session),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('room order', () {
    test('rooms sort the way people read them', () {
      final List<PatientSummary> list = <PatientSummary>[
        _summary('a', '509A'),
        _summary('b', ''),
        _summary('c', '412B'),
        _summary('d', '10'),
        _summary('e', '9'),
        _summary('f', '412A'),
      ]..sort(PatientSummary.compareByRoom);
      expect(list.map((PatientSummary p) => p.room), <String>[
        '9',
        '10',
        '412A',
        '412B',
        '509A',
        '',
      ]);
    });

    test('the meta line leaves out blank parts', () {
      expect(_summary('a', '509A').metaLine, '70-79 · F · Room 509A');
      final PatientSummary bare = PatientSummary.fromJson(<String, dynamic>{
        'id': 'x',
        'display_name': 'No Data',
      });
      expect(bare.metaLine, '');
    });
  });

  group('CensusRepositoryImpl', () {
    test('keeps the selected team and orders by room', () async {
      final _Rig r = await _rig(
        (_) => FakeReply(200, <Object>[
          _patient('p1', '509A'),
          _patient('p2', '412B'),
          _patient('p3', '100', team: 'other'),
        ]),
      );
      final Result<List<PatientSummary>> result = await CensusRepositoryImpl(
        r.client,
        r.storage,
      ).loadPatients();
      expect(
        (result as Ok<List<PatientSummary>>).value.map(
          (PatientSummary p) => p.id,
        ),
        <String>['p2', 'p1'],
      );
    });

    test('reads a wrapped list and keeps the summary state', () async {
      final _Rig r = await _rig(
        (_) => FakeReply(200, <String, Object>{
          'patients': <Object>[
            _patient('p1', '1', state: 'Outdated', facts: 3, tasks: 2),
          ],
        }),
      );
      final Result<List<PatientSummary>> result = await CensusRepositoryImpl(
        r.client,
        r.storage,
      ).loadPatients();
      final PatientSummary p =
          (result as Ok<List<PatientSummary>>).value.single;
      expect(p.summaryState, SummaryState.outdated);
      expect(p.unreviewedFacts, 3);
      expect(p.openTasks, 2);
    });

    test('an error becomes a plain failure', () async {
      final _Rig r = await _rig(
        (_) => const FakeReply(403, <String, Object>{
          'error': <String, Object>{'code': 'access_denied', 'message': 'raw'},
        }),
      );
      final Result<List<PatientSummary>> result = await CensusRepositoryImpl(
        r.client,
        r.storage,
      ).loadPatients();
      final Failure failure = (result as Err<List<PatientSummary>>).failure;
      expect(failure.message, isNot(contains('raw')));
    });

    test('add patient posts the five fields', () async {
      final _Rig r = await _rig((_) => FakeReply(201, _patient('new', '7')));
      final Result<PatientSummary> result =
          await CensusRepositoryImpl(r.client, r.storage).addPatient(
            const NewPatient(
              teamId: 't1',
              displayName: 'Fictional One',
              room: '7',
              ageBand: '70-79',
              sex: 'F',
            ),
          );
      expect(result, isA<Ok<PatientSummary>>());
      expect(r.last.method, 'POST');
      expect(r.last.path, '/patients');
      expect(r.last.data, <String, String>{
        'team_id': 't1',
        'display_name': 'Fictional One',
        'room': '7',
        'age_band': '70-79',
        'sex': 'F',
      });
    });
  });

  group('CensusBloc', () {
    test('loads the list, then shows a failure with a message', () async {
      final _FakeCensus repo = _FakeCensus(<PatientSummary>[
        _summary('a', '1'),
      ]);
      final CensusBloc bloc = CensusBloc(repo)..add(const CensusRequested());
      await bloc.stream.firstWhere(
        (CensusState s) => s.status == CensusStatus.ready,
      );
      expect(bloc.state.patients.single.id, 'a');

      repo.fail = true;
      bloc.add(const CensusRequested());
      final CensusState failed = await bloc.stream.firstWhere(
        (CensusState s) => s.status == CensusStatus.failure,
      );
      expect(failed.error, isNotEmpty);
      // The last list stays, so the screen is not blanked by a bad refresh.
      expect(failed.patients.single.id, 'a');
      await bloc.close();
    });

    test('a first load that fails has no list and an error', () async {
      final CensusBloc bloc = CensusBloc(
        _FakeCensus(const <PatientSummary>[])..fail = true,
      )..add(const CensusRequested());
      final CensusState state = await bloc.stream.firstWhere(
        (CensusState s) => s.status == CensusStatus.failure,
      );
      expect(state.patients, isEmpty);
      await bloc.close();
    });

    test('adding a patient reloads the list', () async {
      final _FakeCensus repo = _FakeCensus(<PatientSummary>[]);
      final CensusBloc bloc = CensusBloc(repo)..add(const CensusRequested());
      await bloc.stream.firstWhere(
        (CensusState s) => s.status == CensusStatus.ready,
      );
      bloc.add(
        const PatientAddRequested(
          NewPatient(
            teamId: 't1',
            displayName: 'X',
            room: '5',
            ageBand: '70-79',
            sex: 'F',
          ),
        ),
      );
      final CensusState done = await bloc.stream.firstWhere(
        (CensusState s) => s.patients.length == 1 && s.addedCount == 1,
      );
      expect(done.adding, isFalse);
      await bloc.close();
    });

    test('a failed add keeps the sheet open with an error', () async {
      final _FakeCensus repo = _FakeCensus(<PatientSummary>[])..failAdd = true;
      final CensusBloc bloc = CensusBloc(repo);
      bloc.add(
        const PatientAddRequested(
          NewPatient(
            teamId: 't1',
            displayName: 'X',
            room: '5',
            ageBand: '70-79',
            sex: 'F',
          ),
        ),
      );
      final CensusState state = await bloc.stream.firstWhere(
        (CensusState s) => s.addError != null,
      );
      expect(state.addedCount, 0);
      await bloc.close();
    });
  });

  group('PatientRepositoryImpl', () {
    test('reads the detail and the plan as lines', () async {
      final _Rig r = await _rig(
        (_) => FakeReply(200, <String, Object>{
          ..._patient('p1', '509A'),
          'revision': 4,
          'plan_today': 'Continue diuresis\nRecheck BMP',
          'missing_information': <Object>["Today's exam"],
          'conflicts': <Object>[
            <String, Object>{'label': 'Weight', 'text': 'Two values differ'},
          ],
          'trends': <Object>['Creatinine rising'],
          'problems': <Object>[
            <String, Object>{'id': 'pr1', 'label': 'AKI', 'state': 'suggested'},
          ],
        }),
      );
      final Result<PatientDetail> result = await PatientRepositoryImpl(
        r.client,
      ).loadDetail('p1');
      final PatientDetail d = (result as Ok<PatientDetail>).value;
      expect(d.revision, 4);
      expect(d.planToday, <String>['Continue diuresis', 'Recheck BMP']);
      expect(d.missingInformation, <String>["Today's exam"]);
      expect(d.conflicts.single.label, 'Weight');
      expect(d.trends.single.text, 'Creatinine rising');
      expect(d.problems.single.state.label, 'Suggested by AI');
    });

    test('no baseline is its own state', () async {
      final _Rig r = await _rig(
        (_) => const FakeReply(200, <String, Object>{'status': 'no_baseline'}),
      );
      final PatientChanges c =
          ((await PatientRepositoryImpl(r.client).loadChanges('p1'))
                  as Ok<PatientChanges>)
              .value;
      expect(c.hasBaseline, isFalse);
      expect(r.last.path, '/patients/p1/changes');
    });

    test('changes keep their items', () async {
      final _Rig r = await _rig(
        (_) => const FakeReply(200, <String, Object>{
          'status': 'ok',
          'changes': <Object>['Creatinine 1.2 to 1.7'],
        }),
      );
      final PatientChanges c =
          ((await PatientRepositoryImpl(r.client).loadChanges('p1'))
                  as Ok<PatientChanges>)
              .value;
      expect(c.hasBaseline, isTrue);
      expect(c.items.single.text, 'Creatinine 1.2 to 1.7');
    });

    test('the plan is saved with PUT', () async {
      final _Rig r = await _rig(
        (_) => const FakeReply(200, <String, Object>{}),
      );
      await PatientRepositoryImpl(r.client).savePlan('p1', <String>['a', 'b']);
      expect(r.last.method, 'PUT');
      expect(r.last.path, '/patients/p1/plan');
      expect(r.last.data, <String, String>{'text': 'a\nb'});
    });
  });

  group('PatientOverviewBloc', () {
    test('loads the detail and the changes', () async {
      final PatientOverviewBloc bloc = PatientOverviewBloc(
        _FakePatients(),
        'p1',
      )..add(const PatientOverviewRequested());
      final PatientOverviewState s = await bloc.stream.firstWhere(
        (PatientOverviewState s) => s.status == PatientOverviewStatus.ready,
      );
      expect(s.detail!.patient.id, 'p1');
      expect(s.changes!.hasBaseline, isFalse);
      await bloc.close();
    });

    test('failed changes do not hide the patient', () async {
      final PatientOverviewBloc bloc = PatientOverviewBloc(
        _FakePatients()..changesFail = true,
        'p1',
      )..add(const PatientOverviewRequested());
      final PatientOverviewState s = await bloc.stream.firstWhere(
        (PatientOverviewState s) => s.status == PatientOverviewStatus.ready,
      );
      expect(s.changesFailed, isTrue);
      expect(s.detail, isNotNull);
      await bloc.close();
    });

    test('no access is flagged so the screen can go back', () async {
      final PatientOverviewBloc bloc = PatientOverviewBloc(
        _FakePatients()..denied = true,
        'p1',
      )..add(const PatientOverviewRequested());
      final PatientOverviewState s = await bloc.stream.firstWhere(
        (PatientOverviewState s) => s.status == PatientOverviewStatus.failure,
      );
      expect(s.accessDenied, isTrue);
      await bloc.close();
    });
  });

  group('ChartDataRepositoryImpl', () {
    test('adds a source, then extracts it', () async {
      final _Rig r = await _rig(
        (RequestOptions o) => o.path.endsWith('/extract')
            ? const FakeReply(200, <String, Object>{})
            : const FakeReply(201, <String, Object>{
                'id': 's9',
                'kind': 'labs',
              }),
      );
      final ChartDataRepositoryImpl repo = ChartDataRepositoryImpl(r.client);
      final Result<ChartSource> saved = await repo.addSource(
        'p1',
        kind: ChartSourceKind.labs,
        time: DateTime.utc(2026, 11, 12, 9, 30),
        text: 'Cr 1.7',
      );
      expect((saved as Ok<ChartSource>).value.id, 's9');
      expect(r.last.path, '/patients/p1/sources');
      expect(r.last.data, <String, String>{
        'kind': 'labs',
        'event_time': '2026-11-12T09:30:00.000Z',
        'text': 'Cr 1.7',
      });
      await repo.extract('p1', 's9');
      expect(r.last.method, 'POST');
      expect(r.last.path, '/patients/p1/sources/s9/extract');
    });

    test('asks only for pending facts and parses them', () async {
      final _Rig r = await _rig(
        (_) => const FakeReply(200, <String, Object>{
          'facts': <Object>[
            <String, Object>{
              'id': 'f1',
              'name': 'Creatinine',
              'value': '1.7',
              'unit': 'mg/dL',
              'passage': 'Cr 1.7 this morning',
            },
          ],
        }),
      );
      final Result<List<Fact>> result = await ChartDataRepositoryImpl(
        r.client,
      ).pendingFacts('p1');
      expect(r.last.queryParameters, <String, dynamic>{'status': 'pending'});
      final Fact f = (result as Ok<List<Fact>>).value.single;
      expect(f.status, FactStatus.pending);
      expect(f.eventTime, isNull, reason: 'unknown time stays unknown');
      expect(f.passage, 'Cr 1.7 this morning');
    });

    test('confirm and reject send the review payload', () async {
      final _Rig r = await _rig(
        (_) => const FakeReply(200, <String, Object>{}),
      );
      final ChartDataRepositoryImpl repo = ChartDataRepositoryImpl(r.client);
      await repo.decide('p1', <String>['f1'], confirm: true);
      expect(r.last.path, '/patients/p1/facts/review');
      expect(r.last.data, <String, Object>{
        'fact_ids': <String>['f1'],
        'status': 'confirmed',
      });
      await repo.decide('p1', <String>['f2'], confirm: false);
      expect(r.last.data, <String, Object>{
        'fact_ids': <String>['f2'],
        'status': 'rejected',
      });
    });

    test('a manual fact sends only what was typed', () async {
      final _Rig r = await _rig(
        (_) => const FakeReply(201, <String, Object>{}),
      );
      await ChartDataRepositoryImpl(
        r.client,
      ).addFact('p1', const NewFact(name: 'O2 flow', value: '2', unit: 'L'));
      expect(r.last.data, <String, Object>{
        'label': 'O2 flow',
        'value': '2',
        'unit': 'L',
      });
    });
  });

  group('FactsReviewBloc', () {
    Fact fact(String id) =>
        Fact(id: id, name: 'Fact $id', value: '1', status: FactStatus.pending);

    test('loads pending facts and toggles selection', () async {
      final FactsReviewBloc bloc = FactsReviewBloc(
        _FakeChart(<Fact>[fact('a'), fact('b')]),
        'p1',
      )..add(const FactsRequested());
      await bloc.stream.firstWhere((FactsReviewState s) => !s.loading);
      bloc
        ..add(const FactToggled('a'))
        ..add(const AllFactsToggled());
      await bloc.stream.firstWhere(
        (FactsReviewState s) => s.selected.length == 2,
      );
      expect(bloc.state.allSelected, isTrue);
      bloc.add(const AllFactsToggled());
      await bloc.stream.firstWhere((FactsReviewState s) => s.selected.isEmpty);
      await bloc.close();
    });

    test('confirming the ticked facts decides each one and reloads', () async {
      final _FakeChart chart = _FakeChart(<Fact>[
        fact('a'),
        fact('b'),
        fact('c'),
      ]);
      final FactsReviewBloc bloc = FactsReviewBloc(chart, 'p1')
        ..add(const FactsRequested());
      await bloc.stream.firstWhere((FactsReviewState s) => !s.loading);
      bloc
        ..add(const FactToggled('a'))
        ..add(const FactToggled('c'));
      await bloc.stream.firstWhere(
        (FactsReviewState s) => s.selected.length == 2,
      );
      bloc.add(const FactsDecided(confirm: true));
      final FactsReviewState done = await bloc.stream.firstWhere(
        (FactsReviewState s) => s.lastDecided == 2 && !s.busy,
      );
      expect(chart.decisions, <String>['a:true', 'c:true']);
      expect(done.facts.map((Fact f) => f.id), <String>['b']);
      expect(done.selected, isEmpty);
      await bloc.close();
    });

    test('rejecting one fact does not touch the others', () async {
      final _FakeChart chart = _FakeChart(<Fact>[fact('a'), fact('b')]);
      final FactsReviewBloc bloc = FactsReviewBloc(chart, 'p1')
        ..add(const FactsRequested());
      await bloc.stream.firstWhere((FactsReviewState s) => !s.loading);
      bloc.add(const FactsDecided(confirm: false, factId: 'b'));
      await bloc.stream.firstWhere(
        (FactsReviewState s) => s.lastDecided == 1 && !s.busy,
      );
      expect(chart.decisions, <String>['b:false']);
      expect(bloc.state.facts.single.id, 'a');
      await bloc.close();
    });

    test('a failed bulk review keeps the facts and reports the count', () async {
      final _FakeChart chart = _FakeChart(<Fact>[fact('a'), fact('b')])
        ..failBatch = true;
      final FactsReviewBloc bloc = FactsReviewBloc(chart, 'p1')
        ..add(const FactsRequested());
      await bloc.stream.firstWhere((FactsReviewState s) => !s.loading);
      bloc.add(const AllFactsToggled());
      await bloc.stream.firstWhere(
        (FactsReviewState s) => s.selected.length == 2,
      );
      bloc.add(const FactsDecided(confirm: true));
      final FactsReviewState done = await bloc.stream.firstWhere(
        (FactsReviewState s) => s.lastFailed == 2 && !s.busy,
      );
      expect(done.lastDecided, 0);
      expect(done.error, isNotNull);
      expect(done.facts.map((Fact f) => f.id), <String>['a', 'b']);
      await bloc.close();
    });

    test('nothing is sent when nothing is ticked', () async {
      final _FakeChart chart = _FakeChart(<Fact>[fact('a')]);
      final FactsReviewBloc bloc = FactsReviewBloc(chart, 'p1')
        ..add(const FactsRequested());
      await bloc.stream.firstWhere((FactsReviewState s) => !s.loading);
      bloc.add(const FactsDecided(confirm: true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(chart.decisions, isEmpty);
      await bloc.close();
    });
  });

  group('AddSourceCubit', () {
    Future<void> submit(AddSourceCubit cubit, {bool extract = true}) {
      return cubit.submit(
        kind: ChartSourceKind.progressNote,
        time: DateTime(2026, 11, 12, 9),
        text: 'note',
        extract: extract,
      );
    }

    test('save then extract finishes', () async {
      final _FakeChart chart = _FakeChart(const <Fact>[]);
      final AddSourceCubit cubit = AddSourceCubit(chart, 'p1');
      await submit(cubit);
      expect(cubit.state.done, isTrue);
      expect(chart.sourcesAdded, 1);
      expect(chart.extracted, <String>['src-1']);
      await cubit.close();
    });

    test('save without reading facts skips extraction', () async {
      final _FakeChart chart = _FakeChart(const <Fact>[]);
      final AddSourceCubit cubit = AddSourceCubit(chart, 'p1');
      await submit(cubit, extract: false);
      expect(cubit.state.done, isTrue);
      expect(chart.extracted, isEmpty);
      await cubit.close();
    });

    test(
      'a failed extraction keeps the saved text. Retry does not resave',
      () async {
        final _FakeChart chart = _FakeChart(const <Fact>[])
          ..extractFails = true;
        final AddSourceCubit cubit = AddSourceCubit(chart, 'p1');
        await submit(cubit);
        expect(cubit.state.done, isFalse);
        expect(cubit.state.error, isNotNull);
        expect(cubit.state.sourceId, 'src-1');

        chart.extractFails = false;
        await submit(cubit);
        expect(cubit.state.done, isTrue);
        expect(chart.sourcesAdded, 1, reason: 'the text was saved only once');
        expect(chart.extracted, <String>['src-1']);
        await cubit.close();
      },
    );

    test('a failed save reports and saves nothing', () async {
      final _FakeChart chart = _FakeChart(const <Fact>[])..saveFails = true;
      final AddSourceCubit cubit = AddSourceCubit(chart, 'p1');
      await submit(cubit);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.sourceId, isNull);
      expect(chart.extracted, isEmpty);
      await cubit.close();
    });
  });

  group('home from the real census', () {
    test('counts chart data and names only deterministic items', () async {
      final HomeRepositoryImpl repo = HomeRepositoryImpl(
        _FakeCensus(<PatientSummary>[
          PatientSummary.fromJson(
            _patient('a', '1', state: 'Draft ready', facts: 2, tasks: 1),
          ),
          PatientSummary.fromJson(_patient('b', '2', state: 'Outdated')),
          PatientSummary.fromJson(_patient('c', '3', tasks: 4)),
        ]),
        await _plainStorage(),
        clock: () => DateTime(2026, 11, 12, 9),
      );
      final HomeSnapshot s = ((await repo.load()) as Ok<HomeSnapshot>).value;
      expect(s.patientCount, 3);
      expect(s.pendingTaskCount, 5);
      expect(s.draftsAwaitingReview, 1);
      expect(s.isSynthetic, isFalse, reason: 'real data is not marked demo');
      expect(s.attention.map((HomeAttentionItem i) => i.title), <String>[
        'Chart facts to review',
        'Summary is outdated',
      ]);
      final String all = <String>[
        s.roundsStatus,
        ...s.attention.map((HomeAttentionItem i) => '${i.title} ${i.detail}'),
        ...s.patients.map(
          (HomePatientPreview p) => '${p.reason} ${p.latestUpdate}',
        ),
      ].join(' ').toLowerCase();
      expect(all, isNot(contains('priority')));
      expect(all, isNot(contains('reassess')));
    });

    test('a census failure is a failure', () async {
      final HomeRepositoryImpl repo = HomeRepositoryImpl(
        _FakeCensus(const <PatientSummary>[])..fail = true,
        await _plainStorage(),
      );
      expect(await repo.load(), isA<Err<HomeSnapshot>>());
    });
  });
}

Future<AppStorage> _plainStorage() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return AppStorage(await SharedPreferences.getInstance());
}

class _FakeCensus implements CensusRepository {
  _FakeCensus(this.patients);

  List<PatientSummary> patients;
  bool fail = false;
  bool failAdd = false;

  @override
  Future<Result<List<PatientSummary>>> loadPatients() async {
    if (fail) {
      return Err<List<PatientSummary>>(ApiFailure(const ApiError.network()));
    }
    return Ok<List<PatientSummary>>(List<PatientSummary>.of(patients));
  }

  @override
  Future<Result<PatientSummary>> addPatient(NewPatient patient) async {
    if (failAdd) {
      return Err<PatientSummary>(ApiFailure(const ApiError.network()));
    }
    final PatientSummary added = _summary('new', patient.room);
    patients = <PatientSummary>[...patients, added];
    return Ok<PatientSummary>(added);
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
  Future<Result<void>> setSortOrder(String patientId, int sortOrder) async {
    patients = <PatientSummary>[
      for (final PatientSummary p in patients)
        if (p.id == patientId)
          PatientSummary(
            id: p.id,
            teamId: p.teamId,
            displayName: p.displayName,
            room: p.room,
            ageBand: p.ageBand,
            sex: p.sex,
            summaryState: p.summaryState,
            unreviewedFacts: p.unreviewedFacts,
            openTasks: p.openTasks,
            sortOrder: sortOrder,
          )
        else
          p,
    ];
    return const Ok<void>(null);
  }
}

class _FakePatients implements PatientRepository {
  bool changesFail = false;
  bool denied = false;

  @override
  Future<Result<PatientDetail>> loadDetail(String patientId) async {
    if (denied) {
      return Err<PatientDetail>(
        ApiFailure(const ApiError(code: 'access_denied', message: 'x')),
      );
    }
    return Ok<PatientDetail>(
      PatientDetail(patient: _summary(patientId, '1'), revision: 1),
    );
  }

  @override
  Future<Result<PatientChanges>> loadChanges(String patientId) async {
    if (changesFail) {
      return Err<PatientChanges>(ApiFailure(const ApiError.network()));
    }
    return const Ok<PatientChanges>(
      PatientChanges(hasBaseline: false, items: <InsightItem>[]),
    );
  }

  @override
  Future<Result<void>> savePlan(String patientId, List<String> lines) async =>
      const Ok<void>(null);
}

class _FakeChart implements ChartDataRepository {
  _FakeChart(List<Fact> facts) : _facts = List<Fact>.of(facts);

  final List<Fact> _facts;
  final List<String> decisions = <String>[];
  final List<String> extracted = <String>[];
  int sourcesAdded = 0;
  bool extractFails = false;
  bool saveFails = false;

  @override
  Future<Result<ChartSource>> addSource(
    String patientId, {
    required ChartSourceKind kind,
    required DateTime time,
    required String text,
  }) async {
    if (saveFails) {
      return Err<ChartSource>(ApiFailure(const ApiError.network()));
    }
    sourcesAdded++;
    return Ok<ChartSource>(ChartSource(id: 'src-$sourcesAdded', kind: kind));
  }

  @override
  Future<Result<List<ChartSource>>> listSources(String patientId) async =>
      const Ok<List<ChartSource>>(<ChartSource>[]);

  @override
  Future<Result<void>> extract(String patientId, String sourceId) async {
    if (extractFails) return Err<void>(ApiFailure(const ApiError.network()));
    extracted.add(sourceId);
    return const Ok<void>(null);
  }

  @override
  Future<Result<List<Fact>>> pendingFacts(String patientId) async {
    return Ok<List<Fact>>(List<Fact>.of(_facts));
  }

  bool failBatch = false;

  @override
  Future<Result<void>> decide(
    String patientId,
    List<String> factIds, {
    required bool confirm,
  }) async {
    if (failBatch) {
      return Err<void>(ApiFailure(const ApiError.network()));
    }
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
