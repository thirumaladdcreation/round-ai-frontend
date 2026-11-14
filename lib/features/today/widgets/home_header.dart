import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/app/app_colors.dart';
import 'package:round_ai/app/app_typography.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/features/chat/chat_unread_badge.dart';
import 'package:round_ai/features/today/models/home_snapshot.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.snapshot,
    required this.onNotifications,
    super.key,
  });

  final HomeSnapshot snapshot;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final int waiting = snapshot.attention.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _HeaderIcon(
          icon: Icons.menu_rounded,
          tooltip: 'Menu',
          onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                snapshot.dateLabel,
                style: AppTypography.caption(color: colors.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                '${snapshot.greeting}, ${snapshot.clinicianName}.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bold(
                  fontSize: 24,
                  height: 1.2,
                  color: colors.navy,
                ),
              ),
            ],
          ),
        ),
        if (_chatAvailable) ...<Widget>[
          _ChatHeaderIcon(
            onPressed: () => context.go(AppRoutes.chat),
          ),
          const SizedBox(width: 4),
        ],
        _HeaderIcon(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          badge: waiting == 0 ? null : '$waiting',
          onPressed: onNotifications,
        ),
        const SizedBox(width: 4),
        _Avatar(
          initials: _initials(snapshot.clinicianName),
          onPressed: () => context.go(AppRoutes.profile),
        ),
      ],
    );
  }

  /// Chat icon needs DI; widget tests may not register the container.
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

/// Chat sits in the Home header (not the bottom bar), with unread count.
class _ChatHeaderIcon extends StatelessWidget {
  const _ChatHeaderIcon({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ChatUnreadBadge badge =
        InjectionContainer.instance.chatUnreadBadge;
    return ValueListenableBuilder<int>(
      valueListenable: badge,
      builder: (BuildContext context, int _, Widget? child) {
        return _HeaderIcon(
          icon: Icons.forum_outlined,
          tooltip: 'Chat',
          badge: badge.label,
          onPressed: onPressed,
        );
      },
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Material(
            color: colors.surface,
            shape: const CircleBorder(),
            elevation: 1.5,
            shadowColor: colors.navy.withValues(alpha: 0.12),
            child: IconButton(
              tooltip: tooltip,
              onPressed: onPressed,
              icon: Icon(icon, color: colors.textPrimary, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            ),
          ),
          if (badge != null)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge!,
                  style: AppTypography.bold(
                    fontSize: 9,
                    height: 1,
                    color: colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.onPressed});

  final String initials;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: colors.primarySoft,
          child: Text(
            initials,
            style: AppTypography.semiBold(fontSize: 12, color: colors.primary),
          ),
        ),
      ),
    );
  }
}
