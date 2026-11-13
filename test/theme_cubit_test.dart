import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/app/theme_cubit.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemeCubit keeps the chosen mode after a new launch', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final AppStorage storage = AppStorage(preferences);
    final ThemeCubit cubit = ThemeCubit(storage);

    expect(cubit.state, ThemeMode.system);

    await cubit.setMode(ThemeMode.light);
    expect(cubit.state, ThemeMode.light);

    final ThemeCubit restored = ThemeCubit(AppStorage(preferences));
    expect(restored.state, ThemeMode.light);

    await cubit.close();
    await restored.close();
  });
}
