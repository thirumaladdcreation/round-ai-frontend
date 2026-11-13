import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_client.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/authentication/repository/auth_repository.dart';
import 'package:round_ai/features/authentication/repository/auth_repository_impl.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/authentication/repository/profile_repository_impl.dart';
import 'package:round_ai/features/authentication/screens/sign_in_screen.dart';
import 'package:round_ai/features/splash/repository/splash_repository.dart';
import 'package:round_ai/features/splash/repository/splash_repository_impl.dart';
import 'package:round_ai/features/splash/screens/splash_screen.dart';
import 'package:round_ai/features/team_selection/models/clinical_team.dart';
import 'package:round_ai/features/team_selection/repository/team_repository_impl.dart';
import 'package:round_ai/shared/widgets/ai_disabled_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_adapter.dart';

Map<String, Object> _me({List<Map<String, Object>>? teams, bool ai = true}) {
  return <String, Object>{
    'user': <String, Object>{
      'id': 'u1',
      'name': 'Dr. Test',
      'email': 'resident@rounds.test',
      'role': 'Resident',
    },
    'teams':
        teams ??
        <Map<String, Object>>[
          <String, Object>{'id': 't1', 'name': 'Team A'},
          <String, Object>{'id': 't2', 'name': 'Team B'},
        ],
    'ai_enabled': ai,
  };
}

const FakeReply _loginOk = FakeReply(200, <String, Object>{
  'token': 'jwt-abc',
  'user': <String, Object>{'id': 'u1', 'name': 'Dr. Test'},
});

class _Rig {
  _Rig(this.adapter, this.storage, this.store, this.client, this.profile);

  final FakeAdapter adapter;
  final AppStorage storage;
  final MemoryTokenStore store;
  final ApiClient client;
  final ProfileRepositoryImpl profile;

  List<String> get paths =>
      adapter.requests.map((RequestOptions r) => r.path).toList();
}

Future<_Rig> _rig(
  FakeReply Function(RequestOptions) handler, {
  Map<String, Object> prefs = const <String, Object>{},
  String? token,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final MemoryTokenStore store = MemoryTokenStore();
  if (token != null) await store.write(token);
  final SessionStore session = SessionStore(store);
  await session.restore();
  final AppStorage storage = AppStorage(
    await SharedPreferences.getInstance(),
    session: session,
  );
  final FakeAdapter adapter = FakeAdapter(handler);
  late final ApiClient client;
  client = ApiClient(
    session: session,
    dio: fakeDio(adapter),
    onUnauthorized: storage.clearAuthSession,
  );
  return _Rig(
    adapter,
    storage,
    store,
    client,
    ProfileRepositoryImpl(client, storage),
  );
}

FakeReply Function(RequestOptions) _server({
  FakeReply me = const FakeReply(200, <String, Object>{}),
  FakeReply login = _loginOk,
}) {
  return (RequestOptions o) => o.path == '/auth/login' ? login : me;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sign-in', () {
    test('logs in, then loads /me, and keeps the token', () async {
      final _Rig r = await _rig(_server(me: FakeReply(200, _me())));
      final AuthRepositoryImpl auth = AuthRepositoryImpl(
        r.client,
        r.storage,
        r.profile,
      );

      final Result<void> result = await auth.signIn(
        email: ' resident@rounds.test ',
        password: 'ChangeMe-12345',
        rememberMe: true,
      );

      expect(result, isA<Ok<void>>());
      expect(r.paths, <String>['/auth/login', '/me']);
      expect(r.adapter.requests.first.data, <String, String>{
        'email': 'resident@rounds.test',
        'password': 'ChangeMe-12345',
      });
      // /me is called with the new token.
      expect(
        r.adapter.requests.last.headers['Authorization'],
        'Bearer jwt-abc',
      );
      expect(await r.store.read(), 'jwt-abc');
      expect(r.profile.current?.user.name, 'Dr. Test');
      expect(r.storage.clinicianName, 'Dr. Test');
      expect(r.storage.rememberMeEnabled, isTrue);
      expect(r.storage.rememberedEmail, 'resident@rounds.test');
    });

    test('without Remember me the token stays in memory', () async {
      final _Rig r = await _rig(_server(me: FakeReply(200, _me())));
      await AuthRepositoryImpl(
        r.client,
        r.storage,
        r.profile,
      ).signIn(email: 'a@b.co', password: 'x', rememberMe: false);
      expect(r.storage.hasAuthToken, isTrue);
      expect(await r.store.read(), isNull);
      expect(r.storage.rememberedEmail, isNull);
    });

    test('a short password is sent. The server decides.', () async {
      final _Rig r = await _rig(_server(me: FakeReply(200, _me())));
      final Result<void> result = await AuthRepositoryImpl(
        r.client,
        r.storage,
        r.profile,
      ).signIn(email: 'a@b.co', password: 'abc', rememberMe: false);
      expect(result, isA<Ok<void>>());
      expect(r.adapter.requests.first.data['password'], 'abc');
    });

    test('empty fields send nothing', () async {
      final _Rig r = await _rig(_server());
      final Result<void> result = await AuthRepositoryImpl(
        r.client,
        r.storage,
        r.profile,
      ).signIn(email: '', password: '', rememberMe: false);
      expect(result, isA<Err<void>>());
      expect(r.adapter.requests, isEmpty);
    });

    test('bad credentials: plain message, no token, no /me', () async {
      final _Rig r = await _rig(
        _server(
          login: const FakeReply(401, <String, Object>{
            'error': <String, Object>{
              'code': 'bad_credentials',
              'message': 'raw',
            },
          }),
        ),
      );
      final Result<void> result = await AuthRepositoryImpl(
        r.client,
        r.storage,
        r.profile,
      ).signIn(email: 'a@b.co', password: 'wrong', rememberMe: true);
      final Failure failure = (result as Err<void>).failure;
      expect(failure.message, 'Email or password is incorrect.');
      expect(r.paths, <String>['/auth/login']);
      expect(r.storage.hasAuthToken, isFalse);
    });

    test('if /me fails after login, the session is cleared', () async {
      final _Rig r = await _rig(
        _server(me: const FakeReply(500, <String, Object>{'x': 1})),
      );
      final Result<void> result = await AuthRepositoryImpl(
        r.client,
        r.storage,
        r.profile,
      ).signIn(email: 'a@b.co', password: 'pw', rememberMe: true);
      expect(result, isA<Err<void>>());
      expect(r.storage.hasAuthToken, isFalse);
      expect(await r.store.read(), isNull);
      expect(r.profile.current, isNull);
    });
  });

  group('team selection data', () {
    test('lists the teams from /me', () async {
      final _Rig r = await _rig(
        _server(me: FakeReply(200, _me())),
        token: 'tok',
      );
      final TeamRepositoryImpl repo = TeamRepositoryImpl(r.profile, r.storage);
      final Result<List<ClinicalTeam>> result = await repo
          .loadAuthorizedTeams();
      expect(
        (result as Ok<List<ClinicalTeam>>).value.map((ClinicalTeam t) => t.id),
        <String>['t1', 't2'],
      );
      expect(await repo.saveSelectedTeam('t2'), isA<Ok<void>>());
      expect(r.storage.selectedTeamId, 't2');
      expect(await repo.saveSelectedTeam('other'), isA<Err<void>>());
      expect(r.storage.selectedTeamId, 't2');
    });
  });

  group('splash routing', () {
    Future<Result<String>> route(
      FakeReply me, {
      String? token = 'tok',
      Map<String, Object> prefs = const <String, Object>{},
      FakeReply Function(RequestOptions)? handler,
    }) async {
      final _Rig r = await _rig(
        handler ?? (_) => me,
        token: token,
        prefs: prefs,
      );
      return SplashRepositoryImpl(r.storage, r.profile).destination();
    }

    test('no token goes to sign-in without any request', () async {
      final _Rig r = await _rig(
        (_) => const FakeReply(200, <String, Object>{}),
      );
      final Result<String> result = await SplashRepositoryImpl(
        r.storage,
        r.profile,
      ).destination();
      expect((result as Ok<String>).value, AppRoutes.signIn);
      expect(r.adapter.requests, isEmpty);
    });

    test('a valid token and a saved team go to Today', () async {
      final Result<String> result = await route(
        FakeReply(200, _me()),
        prefs: <String, Object>{'selected_team_id': 't2'},
      );
      expect((result as Ok<String>).value, AppRoutes.today);
    });

    test('several teams and none saved go to the picker', () async {
      final Result<String> result = await route(FakeReply(200, _me()));
      expect((result as Ok<String>).value, AppRoutes.selectTeam);
    });

    test('a saved team the user lost access to goes to the picker', () async {
      final Result<String> result = await route(
        FakeReply(200, _me()),
        prefs: <String, Object>{'selected_team_id': 'gone'},
      );
      expect((result as Ok<String>).value, AppRoutes.selectTeam);
    });

    test('exactly one team is chosen automatically', () async {
      final _Rig r = await _rig(
        (_) => FakeReply(
          200,
          _me(
            teams: <Map<String, Object>>[
              <String, Object>{'id': 'only', 'name': 'Only team'},
            ],
          ),
        ),
        token: 'tok',
      );
      final Result<String> result = await SplashRepositoryImpl(
        r.storage,
        r.profile,
      ).destination();
      expect((result as Ok<String>).value, AppRoutes.today);
      expect(r.storage.selectedTeamId, 'only');
    });

    test('no teams goes to the picker, which explains it', () async {
      final Result<String> result = await route(
        FakeReply(200, _me(teams: <Map<String, Object>>[])),
      );
      expect((result as Ok<String>).value, AppRoutes.selectTeam);
    });

    test('an expired token ends the session and goes to sign-in', () async {
      final _Rig r = await _rig(
        (_) => const FakeReply(401, <String, Object>{
          'error': <String, Object>{'code': 'unauthenticated', 'message': 'x'},
        }),
        token: 'old',
        prefs: <String, Object>{'selected_team_id': 't1'},
      );
      final Result<String> result = await SplashRepositoryImpl(
        r.storage,
        r.profile,
      ).destination();
      expect((result as Ok<String>).value, AppRoutes.signIn);
      expect(r.storage.hasAuthToken, isFalse);
      expect(await r.store.read(), isNull);
      expect(r.storage.hasSelectedTeam, isFalse);
    });

    test('offline keeps the session and reports the problem', () async {
      final _Rig r = await _rig(
        (RequestOptions o) => FakeReply.fail(
          DioException.connectionError(requestOptions: o, reason: 'down'),
        ),
        token: 'tok',
      );
      final Result<String> result = await SplashRepositoryImpl(
        r.storage,
        r.profile,
      ).destination();
      expect(result, isA<Err<String>>());
      expect(r.storage.hasAuthToken, isTrue);
    });
  });

  group('profile', () {
    test('the AI banner flag follows ai_enabled', () async {
      final _Rig r = await _rig(
        (_) => FakeReply(200, _me(ai: false)),
        token: 'tok',
      );
      expect(r.profile.aiOff, isFalse, reason: 'unknown before /me');
      await r.profile.load();
      expect(r.profile.aiOff, isTrue);
      expect(r.profile.teamById('t1')?.name, 'Team A');
      expect(r.profile.teamById('zzz'), isNull);
      expect(r.profile.nameOr('x'), 'Dr. Test');
    });

    test('ai_enabled true hides the banner flag', () async {
      final _Rig r = await _rig((_) => FakeReply(200, _me()), token: 'tok');
      await r.profile.load();
      expect(r.profile.aiOff, isFalse);
    });

    test('clear forgets the profile and notifies listeners', () async {
      final _Rig r = await _rig((_) => FakeReply(200, _me()), token: 'tok');
      await r.profile.load();
      int notified = 0;
      r.profile.changes.addListener(() => notified++);
      r.profile.clear();
      expect(r.profile.current, isNull);
      expect(notified, 1);
    });

    test('sign-out clears token, secure storage, team and name', () async {
      final _Rig r = await _rig(
        (_) => FakeReply(200, _me()),
        token: 'tok',
        prefs: <String, Object>{
          'selected_team_id': 't1',
          'clinician_name': 'Dr. Test',
        },
      );
      await r.profile.load();
      r.profile.clear();
      await r.storage.clearAuthSession();
      expect(r.storage.hasAuthToken, isFalse);
      expect(await r.store.read(), isNull);
      expect(r.storage.hasSelectedTeam, isFalse);
      expect(r.profile.current, isNull);
    });
  });

  group('screens', () {
    testWidgets('the AI banner explains that AI is off', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AiDisabledBanner())),
      );
      expect(find.textContaining('AI drafts are turned off'), findsOneWidget);
    });

    testWidgets('sign-in shows the plain server-side error', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final _RecordingAuth auth = _RecordingAuth();
      await tester.pumpWidget(
        MaterialApp(home: SignInScreen(repository: auth)),
      );
      await tester.pump();

      await tester.enterText(
        find.byType(EditableText).at(0),
        'resident@rounds.test',
      );
      // Only 3 characters: no client-side length rule.
      await tester.enterText(find.byType(EditableText).at(1), 'abc');
      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump();

      expect(auth.calls, 1);
      expect(auth.lastPassword, 'abc');
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(find.textContaining('at least 6'), findsNothing);
    });

    testWidgets('splash offers Try again when /me cannot be reached', (
      tester,
    ) async {
      final _FlakySplash repo = _FlakySplash();
      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => SplashScreen(repository: repo),
          ),
          GoRoute(
            path: AppRoutes.today,
            builder: (_, _) => const Scaffold(body: Text('TODAY')),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Sign in again'), findsOneWidget);
      expect(find.text('TODAY'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(repo.calls, 2);
      expect(find.text('TODAY'), findsOneWidget);
    });
  });
}

class _RecordingAuth implements AuthRepository {
  int calls = 0;
  String? lastPassword;

  @override
  Future<Result<void>> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    calls++;
    lastPassword = password;
    return Err<void>(
      ApiFailure(const ApiError(code: 'bad_credentials', message: 'raw')),
    );
  }
}

class _FlakySplash implements SplashRepository {
  int calls = 0;

  @override
  Future<Result<String>> destination() async {
    calls++;
    if (calls == 1) {
      return Err<String>(ApiFailure(const ApiError.network()));
    }
    return const Ok<String>(AppRoutes.today);
  }
}
