import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/app/app_constants.dart';
import 'package:round_ai/app/app_router.dart';
import 'package:round_ai/app/app_theme.dart';
import 'package:round_ai/app/theme_cubit.dart';
import 'package:round_ai/core/utils/screen_utils.dart';
import 'package:round_ai/shared/widgets/environment_banner.dart';
import 'package:round_ai/shared/widgets/mock_ai_banner.dart';
import 'package:round_ai/shared/widgets/privacy_shield.dart';
import 'package:round_ai/shared/widgets/web_phone_shell.dart';

class RoundsApp extends StatelessWidget {
  const RoundsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (BuildContext context, ThemeMode mode) {
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          routerConfig: AppRouter.router,
          builder: (BuildContext context, Widget? child) {
            ScreenUtils.init(context);
            return WebPhoneShell(
              child: GestureDetector(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                behavior: HitTestBehavior.translucent,
                child: PrivacyShield(
                  child: EnvironmentBanner(
                    child: MockAiBanner(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
