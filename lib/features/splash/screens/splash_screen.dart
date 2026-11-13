import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/splash/widgets/splash_backdrop.dart';
import 'package:round_ai/features/splash/bloc/splash_bloc.dart';
import 'package:round_ai/features/splash/bloc/splash_event.dart';
import 'package:round_ai/features/splash/bloc/splash_state.dart';
import 'package:round_ai/features/splash/repository/splash_repository.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({this.repository, super.key});

  final SplashRepository? repository;

  @override
  Widget build(BuildContext context) {
    final SplashRepository source =
        repository ?? InjectionContainer.instance.splashRepository;
    return BlocProvider<SplashBloc>(
      create: (_) => SplashBloc(source)..add(const SplashStarted()),
      child: const SplashArtwork(),
    );
  }
}

class SplashArtwork extends StatelessWidget {
  const SplashArtwork({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SplashBloc, SplashState>(
      listenWhen: (_, SplashState next) => next is SplashReady,
      listener: (BuildContext context, SplashState state) {
        if (state is SplashReady) context.go(state.route);
      },
      child: Stack(
        children: <Widget>[
          const SplashBackdrop(),
          BlocBuilder<SplashBloc, SplashState>(
            builder: (BuildContext context, SplashState state) {
              if (state is! SplashFailed) return const SizedBox.shrink();
              return SplashRetryPanel(message: state.message);
            },
          ),
        ],
      ),
    );
  }
}

/// Shown when the saved session could not be checked. The user can try again
/// or go to sign-in.
class SplashRetryPanel extends StatelessWidget {
  const SplashRetryPanel({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Material(
            color: RoundsBrand.charcoal,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTypography.inter(
                      AppTypography.regular(
                        color: RoundsBrand.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppButton(
                    label: 'Try again',
                    useInter: true,
                    backgroundColor: RoundsBrand.aqua,
                    foregroundColor: RoundsBrand.charcoal,
                    onPressed: () =>
                        context.read<SplashBloc>().add(const SplashStarted()),
                  ),
                  TextButton(
                    onPressed: () async {
                      await InjectionContainer.instance.logout();
                      if (context.mounted) context.go(AppRoutes.signIn);
                    },
                    child: Text(
                      'Sign in again',
                      style: AppTypography.inter(
                        AppTypography.semiBold(
                          color: RoundsBrand.aqua,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
