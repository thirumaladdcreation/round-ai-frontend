import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/authentication/widgets/sign_in_lockup.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.snapshot,
    required this.onNotifications,
    super.key,
  });

  final HomeSnapshot snapshot;
  final VoidCallback onNotifications;

  static const Color _navy = Color(0xFF15252F);
  static const Color _teal = Color(0xFF0A8F9C);

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final int waiting = snapshot.attention.length;
    final Color ink = dark ? colors.textPrimary : _navy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: InkWell(
                onTap: () => Scaffold.maybeOf(context)?.openDrawer(),
                borderRadius: BorderRadius.circular(8),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: SignInWordmark(width: 128),
                  ),
                ),
              ),
            ),
            if (_chatAvailable) ...<Widget>[
              _ChatHeaderIcon(onPressed: () => context.go(AppRoutes.chat)),
              const SizedBox(width: 2),
            ],
            _HeaderIcon(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              badge: waiting == 0 ? null : '$waiting',
              onPressed: onNotifications,
            ),
            const SizedBox(width: 2),
            _Avatar(
              initials: _initials(snapshot.clinicianName),
              onPressed: () => context.go(AppRoutes.profile),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          snapshot.dateLabel,
          style: AppTypography.semiBold(
            fontSize: 18,
            height: 24 / 18,
            color: ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _countsLine(snapshot),
          style: AppTypography.regular(
            fontSize: 14,
            height: 20 / 14,
            color: dark ? colors.textSecondary : const Color(0xFF5B6B7A),
          ),
        ),
      ],
    );
  }

  String _countsLine(HomeSnapshot snapshot) {
    final List<String> parts = <String>[
      if (snapshot.patientCount > 0)
        snapshot.patientCount == 1
            ? '1 patient'
            : '${snapshot.patientCount} patients',
      if (snapshot.pendingTaskCount > 0)
        snapshot.pendingTaskCount == 1
            ? '1 open task'
            : '${snapshot.pendingTaskCount} open tasks',
      if (snapshot.draftsAwaitingReview > 0)
        snapshot.draftsAwaitingReview == 1
            ? '1 draft to review'
            : '${snapshot.draftsAwaitingReview} drafts to review',
    ];
    if (parts.isEmpty) return snapshot.greeting;
    return parts.join(' · ');
  }

  bool get _chatAvailable {
    if (!AppFeatures.chat) return false;
    try {
      InjectionContainer.instance.chatUnreadBadge;
      return true;
    } catch (_) {
      return false;
    }
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

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badge,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: colors.textPrimary),
        ),
        if (badge != null)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors.error,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChatHeaderIcon extends StatelessWidget {
  const _ChatHeaderIcon({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: InjectionContainer.instance.chatUnreadBadge,
      builder: (BuildContext context, int total, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            IconButton(
              tooltip: 'Chat',
              onPressed: onPressed,
              icon: Icon(Icons.forum_outlined, color: colors.textPrimary),
            ),
            if (total > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.onPressed});

  final String initials;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: HomeHeader._teal,
          child: Text(
            initials,
            style: AppTypography.semiBold(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
