import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/constants/app_constants.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/repository/home_repository.dart';
import 'package:round_ai/features/today/repository/demo_home_repository.dart';
import 'package:round_ai/features/today/screens/today_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppFeatures.forceAll = true);
  tearDown(() => AppFeatures.forceAll = null);

  testWidgets('home screen focuses on greeting, primary CTA, and patients', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.clinicianNameKey: 'Dr. Alex',
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final DemoHomeRepository repository = DemoHomeRepository(
      AppStorage(preferences),
      clock: () => DateTime(2026, 11, 2, 15),
    );

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: TodayScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Good afternoon'), findsOneWidget);
    expect(find.textContaining('Dr. Alex'), findsOneWidget);
    expect(find.text('Start New Round'), findsOneWidget);
    expect(find.text('Recent Patients'), findsOneWidget);
    expect(find.text('RoundsAI Assistant'), findsOneWidget);
    // Repetitive rounds / prepare CTAs are gone from Home.
    expect(find.text('Open rounds'), findsNothing);
    expect(find.text('Prepare for Rounds'), findsNothing);
    expect(find.text("Today's Rounds"), findsNothing);
    expect(find.text('My Patients'), findsNothing);
    await tester.scrollUntilVisible(find.textContaining('509A'), 200);
    expect(find.textContaining('509A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home screen shows an empty census', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TodayScreen(
          repository: _FixedHomeRepository(const Ok<HomeSnapshot>(_empty)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No patients are assigned to this team.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home screen shows a load error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TodayScreen(
          repository: _FixedHomeRepository(
            Err<HomeSnapshot>(UnknownFailure('Team list unavailable.')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Team list unavailable.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FixedHomeRepository implements HomeRepository {
  const _FixedHomeRepository(this.result);

  final Result<HomeSnapshot> result;

  @override
  Future<Result<HomeSnapshot>> load() async => result;
}

const HomeSnapshot _empty = HomeSnapshot(
  clinicianName: 'Dr. Alex',
  greeting: 'Good evening',
  dateLabel: 'Monday, November 2',
  patientCount: 0,
  pendingTaskCount: 0,
  draftsAwaitingReview: 0,
  roundsStatus: 'Preparation has not been started',
  latestChartStamp: 'No chart stamp on this list',
  patients: <HomePatientPreview>[],
  attention: <HomeAttentionItem>[],
  isSynthetic: true,
  hasPartialChart: false,
);
