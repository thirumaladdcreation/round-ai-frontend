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
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_adapter.dart';

PatientSummary _p(String id, String room, {int sort = 0}) => PatientSummary(
  id: id,
  teamId: 't1',
  displayName: 'Patient $id',
  room: room,
  ageBand: '50s',
  sex: 'F',
  summaryState: SummaryState.notGenerated,
  unreviewedFacts: 0,
  openTasks: 0,
  sortOrder: sort,
);

Future<({ApiClient client, AppStorage storage})> _ready(
  FakeAdapter adapter,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'selected_team_id': 't1',
  });
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final SessionStore session = SessionStore(MemoryTokenStore());
  await session.save('tok', persist: false);
  final AppStorage storage = AppStorage(prefs, session: session);
  return (
    client: ApiClient(session: session, dio: fakeDio(adapter)),
    storage: storage,
  );
}

class _FakeCensus implements CensusRepository {
  _FakeCensus(this.patients);

  List<PatientSummary> patients;
  final List<(String, int)> sortCalls = <(String, int)>[];

  @override
  Future<Result<List<PatientSummary>>> loadPatients() async =>
      Ok<List<PatientSummary>>(List<PatientSummary>.of(patients));

  @override
  Future<Result<PatientSummary>> addPatient(NewPatient patient) async =>
      Err<PatientSummary>(ApiFailure(const ApiError.network()));

  @override
  Future<Result<CensusIntakeProposal>> intakeCensus({
    required TempMedia media,
    required String idempotencyKey,
    String? teamId,
    CancelToken? cancelToken,
  }) async => throw UnimplementedError();

  @override
  Future<Result<CensusConfirmResult>> confirmCensus(
    String intakeId, {
    required List<ProposedCensusPatient> items,
  }) async => throw UnimplementedError();

  @override
  Future<Result<CensusExport>> exportCensus({String? teamId}) async =>
      const Ok<CensusExport>(CensusExport(text: ''));

  @override
  Future<Result<void>> setSortOrder(String patientId, int sortOrder) async {
    sortCalls.add((patientId, sortOrder));
    patients = <PatientSummary>[
      for (final PatientSummary p in patients)
        if (p.id == patientId) p.copyWith(sortOrder: sortOrder) else p,
    ];
    return const Ok<void>(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('census intake models', () {
    test('parses proposal and builds confirm payload with skip/edits', () {
      final CensusIntakeProposal proposal = CensusIntakeProposal.fromJson(
        <String, dynamic>{
          'id': 'intake1',
          'note': 'Proposed only',
          'source_text': '401 | Alex | 50s | M | cough',
          'patients': <Object>[
            <String, Object>{
              'index': 0,
              'display_name': 'Alex',
              'room': '401',
              'age_band': '50s',
              'sex': 'M',
              'one_line_reason': 'cough',
              'source_text': '401 | Alex',
            },
            <String, Object>{
              'index': 1,
              'display_name': 'Jordan',
              'room': '402',
            },
          ],
        },
      );
      expect(proposal.id, 'intake1');
      expect(proposal.patients, hasLength(2));

      final ProposedCensusPatient edited = proposal.patients.first.copyWith(
        displayName: 'Alex Rivera',
        room: '401A',
      );
      final ProposedCensusPatient skipped = proposal.patients.last.copyWith(
        skipped: true,
      );

      expect(edited.toConfirmItem(), <String, Object>{
        'index': 0,
        'edits': <String, String>{
          'display_name': 'Alex Rivera',
          'room': '401A',
          'age_band': '50s',
          'sex': 'M',
          'one_line_reason': 'cough',
          'source_text': '401 | Alex',
        },
      });
      expect(skipped.toConfirmItem(), <String, Object>{
        'index': 1,
        'skip': true,
      });
    });

    test('confirm result points at first pending-fact patient', () {
      final CensusConfirmResult r = CensusConfirmResult.fromJson(
        <String, dynamic>{
          'intake_id': 'i1',
          'created': <Object>[
            <String, Object>{'patient_id': 'p0', 'index': 0},
            <String, Object>{
              'patient_id': 'p1',
              'index': 1,
              'fact_id': 'f9',
            },
          ],
        },
      );
      expect(r.firstFactsPatientId, 'p1');
    });
  });

  group('CensusRepositoryImpl scribe endpoints', () {
    test('confirm sends items payload', () async {
      final FakeAdapter a = FakeAdapter(
        (RequestOptions o) => FakeReply(200, <String, Object>{
          'intake_id': 'i1',
          'status': 'confirmed',
          'created': <Object>[
            <String, Object>{
              'patient_id': 'p1',
              'index': 0,
              'fact_id': 'f1',
            },
          ],
        }),
      );
      final ready = await _ready(a);
      final CensusRepositoryImpl repo = CensusRepositoryImpl(
        ready.client,
        ready.storage,
      );
      final Result<CensusConfirmResult> r = await repo.confirmCensus(
        'i1',
        items: <ProposedCensusPatient>[
          const ProposedCensusPatient(
            index: 0,
            displayName: 'Alex',
            room: '401',
            oneLineReason: 'cough',
          ),
          const ProposedCensusPatient(
            index: 1,
            displayName: 'Skip me',
            skipped: true,
          ),
        ],
      );
      expect((r as Ok<CensusConfirmResult>).value.created.single.patientId, 'p1');
      expect(a.requests.single.path, '/census/intake/i1/confirm');
      expect(a.requests.single.data, <String, Object>{
        'items': <Map<String, Object>>[
          <String, Object>{
            'index': 0,
            'edits': <String, String>{
              'display_name': 'Alex',
              'room': '401',
              'age_band': '',
              'sex': '',
              'one_line_reason': 'cough',
              'source_text': '',
            },
          },
          <String, Object>{'index': 1, 'skip': true},
        ],
      });
    });

    test('export reads text and note', () async {
      final FakeAdapter a = FakeAdapter(
        (RequestOptions o) => FakeReply(200, <String, Object>{
          'ordered_by': 'sort_order_then_room',
          'text': ' 1. 401 · Alex',
          'note': 'Printable census.',
          'patients': <Object>[
            <String, Object>{'id': 'p1', 'display_name': 'Alex'},
          ],
        }),
      );
      final ready = await _ready(a);
      final Result<CensusExport> r = await CensusRepositoryImpl(
        ready.client,
        ready.storage,
      ).exportCensus();
      final CensusExport exp = (r as Ok<CensusExport>).value;
      expect(exp.text, ' 1. 401 · Alex');
      expect(exp.patientCount, 1);
      expect(a.requests.single.path, '/census/export');
      expect(a.requests.single.queryParameters['team_id'], 't1');
    });

    test('setSortOrder patches the patient', () async {
      final FakeAdapter a = FakeAdapter(
        (RequestOptions o) => FakeReply(200, <String, Object>{'id': 'p1'}),
      );
      final ready = await _ready(a);
      final Result<void> r = await CensusRepositoryImpl(
        ready.client,
        ready.storage,
      ).setSortOrder('p1', 3);
      expect(r, isA<Ok<void>>());
      expect(a.requests.single.method, 'PATCH');
      expect(a.requests.single.path, '/patients/p1');
      expect(a.requests.single.data, <String, int>{'sort_order': 3});
    });
  });

  group('CensusBloc reorder', () {
    test('persists new sort_order for every row', () async {
      final _FakeCensus repo = _FakeCensus(<PatientSummary>[
        _p('a', '1', sort: 0),
        _p('b', '2', sort: 1),
        _p('c', '3', sort: 2),
      ]);
      final CensusBloc bloc = CensusBloc(repo)..add(const CensusRequested());
      await bloc.stream.firstWhere(
        (CensusState s) => s.status == CensusStatus.ready,
      );
      bloc.add(const CensusReorderRequested(oldIndex: 0, newIndex: 2));
      await bloc.stream.firstWhere(
        (CensusState s) => s.patients.first.id == 'b',
      );
      // Wait for all sort_order PATCHes to finish.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.patients.map((PatientSummary p) => p.id), <String>[
        'b',
        'c',
        'a',
      ]);
      expect(repo.sortCalls, <(String, int)>[
        ('b', 0),
        ('c', 1),
        ('a', 2),
      ]);
      await bloc.close();
    });
  });
}
