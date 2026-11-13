import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/constants/app_constants.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';
import 'package:round_ai/features/today/repository/demo_home_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('home snapshot uses the stored clinician and team order', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.clinicianNameKey: 'Dr. Alex',
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final DemoHomeRepository repository = DemoHomeRepository(
      AppStorage(preferences),
      clock: () => DateTime(2026, 11, 2, 9),
    );

    final Result<HomeSnapshot> result = await repository.load();
    final HomeSnapshot snapshot = result.when(
      ok: (HomeSnapshot value) => value,
      err: (failure) => fail(failure.message),
    );

    expect(snapshot.clinicianName, 'Dr. Alex');
    expect(snapshot.greeting, 'Good morning');
    expect(snapshot.draftsAwaitingReview, 0);
    expect(
      snapshot.patients.map((HomePatientPreview p) => p.name).toList(),
      <String>['Rosa Martinez', 'Daniel Brooks', 'Samuel Chen', 'Elena Ruiz'],
    );
    expect(snapshot.patients.first.ageLabel, '76 yrs');
    expect(snapshot.patients.first.genderLabel, 'Woman');
    expect(snapshot.patients[1].ageLabel, '64 yrs');
    expect(snapshot.patients[1].genderLabel, 'Man');
    expect(snapshot.patients[3].genderLabel, 'Woman');
    expect(snapshot.pendingTaskCount, 4);
    expect(snapshot.isSynthetic, isTrue);
  });
}
