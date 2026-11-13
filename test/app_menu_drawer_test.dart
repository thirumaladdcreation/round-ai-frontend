import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/app/theme_cubit.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:round_ai/features/today/repository/demo_home_repository.dart';
import 'package:round_ai/features/today/screens/today_screen.dart';
import 'package:round_ai/shared/widgets/app_menu_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('menu button opens the left drawer', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await InjectionContainer.instance.init(tokenStore: MemoryTokenStore());

    await tester.pumpWidget(
      BlocProvider<ThemeCubit>(
        create: (_) => ThemeCubit(InjectionContainer.instance.appStorage),
        child: MaterialApp(
          home: Scaffold(
            drawer: const AppMenuDrawer(),
            body: TodayScreen(
              repository: DemoHomeRepository(
                InjectionContainer.instance.appStorage,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Switch team'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
