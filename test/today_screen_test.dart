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

  // The demo repository shows every demo action.
  setUp(() => AppFeatures.forceAll = true);
  tearDown(() => AppFeatures.forceAll = null);

  testWidgets('home screen shows the stored clinician and team list', (
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
    expect(find.text('Monday, November 2'), findsOneWidget);
    expect(find.text("Today's Rounds"), findsOneWidget);
    expect(find.text('Prepare for Rounds'), findsOneWidget);
    expect(find.textContaining('No generated draft'), findsOneWidget);
    expect(
      find.text('1 chart fact is waiting for review'),
      findsWidgets,
    );
    expect(find.textContaining('early reassessment'), findsNothing);
    expect(find.text('Open rounds'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Room 509A'), 200);
    expect(find.textContaining('Room 509A'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Draft a Note'), 200);
    expect(find.text('Teach Me'), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.text('No patients are assigned to this team.'),
      200,
    );
    expect(find.text('No patients are assigned to this team.'), findsOneWidget);
    expect(find.text('No pending tasks'), findsOneWidget);
    expect(find.text('No drafts waiting'), findsOneWidget);
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
