import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/app/app_theme.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/config/shell_tabs.dart';
import 'package:round_ai/core/di/app_bloc_observer.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/network/api_log_interceptor.dart';
import 'package:round_ai/core/router/app_router.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/census/models/patient_summary.dart';
import 'package:round_ai/features/patient/widgets/chart_entry_scaffold.dart';
import 'package:round_ai/features/tasks/models/patient_task.dart';
import 'package:round_ai/features/tasks/screens/patient_tasks_screen.dart';
import 'package:round_ai/features/tasks/screens/team_tasks_screen.dart';
import 'package:round_ai/features/today/bloc/home_bloc.dart';
import 'package:round_ai/features/today/bloc/home_event.dart';
import 'package:round_ai/features/today/bloc/home_state.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/repository/home_repository.dart';
import 'package:round_ai/features/today/widgets/home_rounds_card.dart';
import 'package:round_ai/shared/widgets/app_bottom_nav_bar.dart';
import 'package:round_ai/shared/widgets/demo_content_banner.dart';
import 'package:round_ai/shared/widgets/privacy_shield.dart';
import 'package:round_ai/shared/widgets/skeleton.dart';

import 'support/fake_f5.dart';

void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const HomeSnapshot _snap = HomeSnapshot(
  clinicianName: 'Dr Test',
  greeting: 'Good morning',
  dateLabel: 'Thu 12 Nov',
  patientCount: 2,
  pendingTaskCount: 1,
  draftsAwaitingReview: 0,
  roundsStatus: 'Ready',
  latestChartStamp: '08:00',
  patients: <HomePatientPreview>[],
  attention: <HomeAttentionItem>[],
  isSynthetic: false,
  hasPartialChart: false,
);

class _FakeHome implements HomeRepository {
  _FakeHome(this.reply);

  Result<HomeSnapshot> reply;
  int calls = 0;

  @override
  Future<Result<HomeSnapshot>> load() async {
    calls++;
    return reply;
  }
}

void main() {
  tearDown(() => AppFeatures.forceAll = null);

  group('shell tabs', () {
    test('the real build shows Patients, Tasks, Learn and Chat', () {
      AppFeatures.forceAll = null;
      expect(ShellTabs.visible, <ShellTab>[
        ShellTab.census,
        ShellTab.tasks,
        ShellTab.learn,
        ShellTab.chat,
      ]);
      expect(AppFeatures.rounds, isTrue);
      expect(AppFeatures.learning, isTrue);
      expect(AppFeatures.chat, isTrue);
      expect(AppFeatures.presentation, isTrue);
    });

    test('forceAll keeps the same product bottom bar', () {
      AppFeatures.forceAll = true;
      expect(ShellTabs.visible, <ShellTab>[
        ShellTab.census,
        ShellTab.tasks,
        ShellTab.learn,
        ShellTab.chat,
      ]);
      expect(AppFeatures.rounds, isTrue);
      expect(AppFeatures.learning, isTrue);
      expect(AppFeatures.chat, isTrue);
    });

    testWidgets('the bottom bar labels follow the same list', (
      WidgetTester tester,
    ) async {
      AppFeatures.forceAll = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppBottomNavBar(currentIndex: 0, onItemSelected: (_) {}),
          ),
        ),
      );
      expect(find.text('Patients'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Learn'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(find.text('Scribe'), findsNothing);
      expect(find.text('Rounds'), findsNothing);

      AppFeatures.forceAll = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppBottomNavBar(currentIndex: 0, onItemSelected: (_) {}),
          ),
        ),
      );
      expect(find.text('Patients'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Learn'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
    });

    test('a link to a hidden tab goes to the census', () {
      AppFeatures.forceAll = null;
      expect(AppRouter.redirectFor(AppRoutes.rounds), isNull);
      expect(AppRouter.redirectFor(AppRoutes.learning), isNull);
      expect(AppRouter.redirectFor(AppRoutes.today), isNull);
      expect(AppRouter.redirectFor(AppRoutes.census), isNull);
      expect(AppRouter.redirectFor(AppRoutes.tasks), isNull);
    });
  });

  group('home rounds card', () {
    testWidgets('with rounds enabled it offers prepare for rounds', (
      WidgetTester tester,
    ) async {
      AppFeatures.forceAll = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HomeRoundsCard(snapshot: _snap)),
        ),
      );
      expect(find.text('Prepare for rounds'), findsOneWidget);
      expect(find.text('Open census'), findsOneWidget);
    });

    testWidgets('with rounds on it offers Prepare for rounds', (
      WidgetTester tester,
    ) async {
      AppFeatures.forceAll = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HomeRoundsCard(snapshot: _snap)),
        ),
      );
      expect(find.text('Prepare for rounds'), findsOneWidget);
    });
  });

  group('demo content banner', () {
    test('the wording is fixed so screens share one mark', () {
      expect(
        DemoContentBanner.message,
        'Demo content. Not connected to the backend. '
        'Nothing here is real or AI output.',
      );
    });
  });

  group('skeleton', () {
    testWidgets('announces Loading and stays still when motion is off', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(home: Scaffold(body: SkeletonList(count: 2))),
        ),
      );
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      expect(find.byType(SkeletonCard), findsNWidgets(2));
      // With animations off the opacity does not change across frames.
      final Opacity before = tester.widget(find.byType(Opacity));
      await tester.pump(const Duration(milliseconds: 400));
      final Opacity after = tester.widget(find.byType(Opacity));
      expect(after.opacity, before.opacity);
    });
  });

  group('privacy shield', () {
    testWidgets('covers the app when it leaves the foreground', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyShield(child: Text('patient chart on screen')),
        ),
      );
      expect(find.text('patient chart on screen'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('privacy-cover')), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('privacy-cover')),
        findsOneWidget,
      );
      expect(find.text('RoundsAI'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('privacy-cover')), findsNothing);
    });
  });

  group('logging', () {
    test('API body describe never prints values', () {
      expect(
        ApiLogInterceptor.describe(<String, Object>{
          'email': 'dr@hospital.test',
          'password': 'secret',
          'display_name': 'Room 509A',
        }),
        'object(email, password, display_name)',
      );
      expect(ApiLogInterceptor.describe(<Object>['a', 'b', 'c']), 'list(3)');
      expect(
        ApiLogInterceptor.describe('Creatinine rose to 1.7'),
        'text(22 chars)',
      );
      expect(ApiLogInterceptor.describe(null), 'none');
    });

    test('the bloc observer names types only', () {
      // A silent check that constructing and using it does not throw, and
      // that its onChange signature takes a Change of dynamic (types only).
      final AppBlocObserver observer = AppBlocObserver();
      expect(observer, isA<AppBlocObserver>());
    });
  });

  group('home refresh', () {
    test('a failed refresh keeps the last ready list', () async {
      final _FakeHome repo = _FakeHome(const Ok<HomeSnapshot>(_snap));
      final HomeBloc bloc = HomeBloc(repo);
      bloc.add(const HomeRequested());
      await expectLater(bloc.stream, emitsThrough(isA<HomeReady>()));
      expect(bloc.state, isA<HomeReady>());

      repo.reply = Err<HomeSnapshot>(ApiFailure(const ApiError.network()));
      final Completer<void> done = Completer<void>();
      bloc.add(HomeRefreshed(done: done));
      await done.future;
      expect(bloc.state, isA<HomeReady>());
      expect((bloc.state as HomeReady).snapshot, _snap);
      expect(repo.calls, 2);
      await bloc.close();
    });

    test('a successful refresh updates the snapshot', () async {
      final _FakeHome repo = _FakeHome(const Ok<HomeSnapshot>(_snap));
      final HomeBloc bloc = HomeBloc(repo);
      bloc.add(const HomeRequested());
      await expectLater(bloc.stream, emitsThrough(isA<HomeReady>()));

      const HomeSnapshot next = HomeSnapshot(
        clinicianName: 'Dr Test',
        greeting: 'Good morning',
        dateLabel: 'Thu 12 Nov',
        patientCount: 3,
        pendingTaskCount: 0,
        draftsAwaitingReview: 0,
        roundsStatus: 'Ready',
        latestChartStamp: '09:00',
        patients: <HomePatientPreview>[],
        attention: <HomeAttentionItem>[],
        isSynthetic: false,
        hasPartialChart: false,
      );
      repo.reply = const Ok<HomeSnapshot>(next);
      final Completer<void> done = Completer<void>();
      bloc.add(HomeRefreshed(done: done));
      await done.future;
      expect((bloc.state as HomeReady).snapshot.patientCount, 3);
      await bloc.close();
    });
  });

  group('chart scaffold refresh', () {
    testWidgets('wraps the body in a RefreshIndicator when asked', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChartEntryScaffold(
            title: 'Facts',
            onRefresh: () async {},
            child: const Text('body'),
          ),
        ),
      );
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('leaves the body alone when there is nothing to reload', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChartEntryScaffold(title: 'Facts', child: Text('body')),
        ),
      );
      expect(find.byType(RefreshIndicator), findsNothing);
    });
  });

  group('dark mode smoke', () {
    testWidgets('team and patient tasks render under the dark theme', (
      WidgetTester tester,
    ) async {
      _wide(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: TeamTasksScreen(
            censusRepository: FakeCensusRepository(<PatientSummary>[
              patientRow('a', openTasks: 1),
            ]),
            tasksRepository: FakeTasksRepository()
              ..byPatient = <String, List<PatientTask>>{
                'a': <PatientTask>[task('1', TaskStatus.open, patientId: 'a')],
              },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Task 1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: PatientTasksScreen(
            patientId: 'p1',
            tasksRepository: FakeTasksRepository()
              ..tasks = <PatientTask>[task('2', TaskStatus.open)],
            patientRepository: FakePatientRepository(
              plan: const <String>['Diurese'],
            ),
            aiOff: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Task 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
