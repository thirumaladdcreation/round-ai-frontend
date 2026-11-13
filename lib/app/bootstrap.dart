import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:round_ai/app/app.dart';
import 'package:round_ai/app/app_router.dart';
import 'package:round_ai/app/theme_cubit.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/di/app_bloc_observer.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/utils/app_log.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    _configureErrorHandling();

    Bloc.observer = AppBlocObserver();

    try {
      await AppEnvironment.initialize();
      AppEnvironment.validate();
    } catch (error, stack) {
      AppLog.section('ENV INIT FAILED', <String, Object?>{
        'ERROR': error,
        'STACK': stack,
      });
      runApp(BootstrapErrorApp(message: error.toString()));
      return;
    }

    AppLog.section('APP START', <String, Object?>{
      'ENV': AppEnvironment.name,
      'BASE_URL': AppEnvironment.baseUrl,
    });

    await InjectionContainer.instance.init();
    // A 401 from the backend ends the session: go back to sign-in.
    InjectionContainer.instance.sessionEnded.addListener(
      () => AppRouter.router.go(AppRoutes.signIn),
    );

    runApp(
      BlocProvider<ThemeCubit>(
        create: (_) => ThemeCubit(InjectionContainer.instance.appStorage),
        child: const RoundsApp(),
      ),
    );
  }

  static void _configureErrorHandling() {
    FlutterError.onError = (details) {
      // A release build prints nothing: an error message or a widget dump
      // can quote what is on screen. Debug builds show the full report.
      if (!kReleaseMode) FlutterError.presentError(details);
      AppLog.section('FLUTTER ERROR', <String, Object?>{
        'EXCEPTION': details.exception.runtimeType.toString(),
        'LIBRARY': details.library,
      });
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      AppLog.section('UNHANDLED ERROR', <String, Object?>{
        'ERROR': error.runtimeType.toString(),
        'STACK': stackTrace,
      });
      return true;
    };
  }
}

class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'App failed to start.\n\n$message',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
