import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/app/theme_mode_picker.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';

/// Left menu for profile, team, appearance, and sign out.
class AppMenuDrawer extends StatelessWidget {
  const AppMenuDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final InjectionContainer di = InjectionContainer.instance;
    final storage = di.appStorage;
    final team = di.profileRepository.teamById(storage.selectedTeamId);
    final String profileEmail = di.profileRepository.current?.user.email ?? '';

    return Drawer(
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            AppMenuHeader(
              name: di.profileRepository.nameOr(storage.clinicianName),
              teamName: team?.name ?? 'No team selected',
              email: profileEmail.isNotEmpty
                  ? profileEmail
                  : storage.rememberedEmail,
            ),
            ListTile(
              leading: Icon(
                Icons.person_outline_rounded,
                color: palette.textPrimary,
              ),
              title: Text(
                'Profile',
                style: AppTypography.bodyLarge(color: palette.textPrimary),
              ),
              onTap: () => _go(context, AppRoutes.profile, replace: true),
            ),
            if (AppFeatures.chat)
              ListTile(
                leading: Icon(
                  Icons.forum_outlined,
                  color: palette.textPrimary,
                ),
                title: Text(
                  'Chat',
                  style: AppTypography.bodyLarge(color: palette.textPrimary),
                ),
                subtitle: Text(
                  'Team channels — like Slack',
                  style: AppTypography.regular(
                    fontSize: 12,
                    color: palette.textSecondary,
                  ),
                ),
                onTap: () => _go(context, AppRoutes.chat, replace: true),
              ),
            ListTile(
              leading: Icon(
                Icons.fact_check_outlined,
                color: palette.textPrimary,
              ),
              title: Text(
                'Team tasks',
                style: AppTypography.bodyLarge(color: palette.textPrimary),
              ),
              onTap: () => _go(context, AppRoutes.tasks, replace: true),
            ),
            ListTile(
              leading: Icon(Icons.groups_outlined, color: palette.textPrimary),
              title: Text(
                'Switch team',
                style: AppTypography.bodyLarge(color: palette.textPrimary),
              ),
              onTap: () => _go(context, AppRoutes.selectTeam, replace: true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Divider(color: palette.border, height: 1),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ThemeModePicker(),
            ),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: palette.error),
              title: Text(
                'Sign out',
                style: AppTypography.bodyLarge(color: palette.error),
              ),
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String route, {bool replace = false}) {
    final GoRouter router = GoRouter.of(context);
    Navigator.pop(context);
    if (replace) {
      router.go(route);
    } else {
      router.push(route);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final GoRouter router = GoRouter.of(context);
    Navigator.pop(context);
    await InjectionContainer.instance.logout();
    router.go(AppRoutes.signIn);
  }
}

class AppMenuHeader extends StatelessWidget {
  const AppMenuHeader({
    required this.name,
    required this.teamName,
    this.email,
    super.key,
  });

  final String name;
  final String teamName;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final String initials = _initials(name);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 24,
            backgroundColor: palette.primary,
            child: Text(
              initials,
              style: AppTypography.semiBold(color: palette.white, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: AppTypography.semiBold(
                    fontSize: 16,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  teamName,
                  style: AppTypography.regular(
                    color: palette.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (email != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    email!,
                    style: AppTypography.caption(color: palette.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final List<String> parts = value
        .replaceAll('.', ' ')
        .split(' ')
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'DR';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}
