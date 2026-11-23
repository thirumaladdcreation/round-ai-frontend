import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/theme_mode_picker.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/theme/app_typography.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/shared/widgets/app_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _goHome(BuildContext context) => context.go(AppRoutes.today);

  @override
  Widget build(BuildContext context) {
    final InjectionContainer di = InjectionContainer.instance;
    final storage = di.appStorage;
    final team = di.profileRepository.teamById(storage.selectedTeamId);
    final String role = di.profileRepository.current?.user.role ?? '';
    final String email =
        (di.profileRepository.current?.user.email ?? '').isNotEmpty
        ? di.profileRepository.current!.user.email
        : (storage.rememberedEmail ?? 'Email not remembered');
    final AppPalette palette = AppPalette.of(context);
    // Profile is a shell branch opened with go(), so the stack cannot pop —
    // back must return to Today instead of exiting the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Back to Today',
                      onPressed: () => _goHome(context),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      'Profile',
                      style: AppTypography.bold(
                        fontSize: 28,
                        color: palette.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  di.profileRepository.nameOr(storage.clinicianName),
                  style: AppTypography.semiBold(
                    fontSize: 18,
                    color: palette.textPrimary,
                  ),
                ),
                if (role.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: AppTypography.regular(color: palette.textSecondary),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  team?.name ?? 'No team selected',
                  style: AppTypography.regular(color: palette.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: AppTypography.regular(color: palette.textSecondary),
                ),
                const SizedBox(height: 24),
                const ThemeModePicker(),
                const Spacer(),
                AppButton(
                  label: 'Sign out',
                  variant: AppButtonVariant.outline,
                  onPressed: () async {
                    await InjectionContainer.instance.logout();
                    if (context.mounted) context.go(AppRoutes.signIn);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
