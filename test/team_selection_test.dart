import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/features/team_selection/models/clinical_team.dart';
import 'package:round_ai/features/team_selection/repository/team_repository.dart';
import 'package:round_ai/features/team_selection/screens/select_team_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/features/authentication/repository/demo_auth_repository.dart';
import 'package:round_ai/features/team_selection/bloc/team_selection_bloc.dart';
import 'package:round_ai/features/team_selection/bloc/team_selection_event.dart';
import 'package:round_ai/features/team_selection/repository/demo_team_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('team selection lists only the assigned demo teams', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SelectTeamScreen(repository: FakeTeamRepository(demoTeams)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Select Your Team'), findsOneWidget);
    expect(find.text('Internal Medicine'), findsOneWidget);
    expect(find.text('12 Patients · Team A'), findsOneWidget);
    expect(find.text('ICU Team'), findsOneWidget);
    expect(find.text('Cardiology Team'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Surgery Team'), 120);
    expect(find.text('Surgery Team'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('one assigned team opens the dashboard without a picker', () async {
    final TeamSelectionBloc bloc = TeamSelectionBloc(
      FakeTeamRepository(<ClinicalTeam>[demoTeams.first]),
    );
    bloc.add(const TeamSelectionStarted());
    await bloc.stream.firstWhere((state) => state.openDashboard);
    expect(bloc.state.selectedId, 'internal-medicine');
    await bloc.close();
  });

  test('an unassigned team cannot be saved', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppStorage storage = AppStorage(
      await SharedPreferences.getInstance(),
    );
    final DemoTeamRepository repository = DemoTeamRepository(storage);
    final Result<void> result = await repository.saveSelectedTeam('not-a-team');
    expect(result, isA<Err<void>>());
    expect(storage.hasSelectedTeam, isFalse);
  });

  test('demo sign-in stores a local session', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppStorage storage = AppStorage(
      await SharedPreferences.getInstance(),
    );
    final DemoAuthRepository repository = DemoAuthRepository(storage);

    final Result<void> denied = await repository.signIn(
      email: 'doctor@hospital.com',
      password: '123',
      rememberMe: false,
    );
    expect(denied, isA<Err<void>>());
    expect(storage.hasAuthToken, isFalse);

    final Result<void> allowed = await repository.signIn(
      email: 'doctor@hospital.com',
      password: 'secret1',
      rememberMe: false,
    );
    expect(allowed, isA<Ok<void>>());
    expect(storage.hasAuthToken, isTrue);
    expect(storage.clinicianName, 'Dr. Rivera');
  });
}

class FakeTeamRepository implements TeamRepository {
  FakeTeamRepository(this.teams);

  final List<ClinicalTeam> teams;

  @override
  String? get savedTeamId => null;

  @override
  Future<Result<List<ClinicalTeam>>> loadAuthorizedTeams() async {
    return Ok<List<ClinicalTeam>>(teams);
  }

  @override
  Future<Result<void>> saveSelectedTeam(String teamId) async {
    return const Ok<void>(null);
  }
}
