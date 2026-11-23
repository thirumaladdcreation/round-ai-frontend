import 'package:flutter/material.dart';
import 'package:round_ai/core/config/shell_tabs.dart';
import 'package:round_ai/core/theme/app_colors.dart';
import 'package:round_ai/core/theme/app_typography.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    required this.currentIndex,
    required this.onItemSelected,
    this.tasksBadge,
    this.chatBadge,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final String? tasksBadge;
  final String? chatBadge;

  /// Only the tabs that are in this build, in the order of the router's
  /// branches.
  List<_NavSpec> get _items => <_NavSpec>[
    for (final ShellTab tab in ShellTabs.visible)
      switch (tab) {
        ShellTab.census => const _NavSpec(
          Icons.groups_outlined,
          Icons.groups_outlined,
          'Patients',
        ),
        ShellTab.tasks => _NavSpec(
          Icons.checklist_outlined,
          Icons.checklist_outlined,
          'Tasks',
          badge: tasksBadge,
        ),
        ShellTab.learn => const _NavSpec(
          Icons.menu_book_outlined,
          Icons.menu_book_outlined,
          'Learn',
        ),
        ShellTab.chat => _NavSpec(
          Icons.forum_outlined,
          Icons.forum_outlined,
          'Chat',
          badge: chatBadge,
        ),
        // Secondary destinations — not in [ShellTabs.visible].
        ShellTab.today => const _NavSpec(
          Icons.home_rounded,
          Icons.home_outlined,
          'Today',
        ),
        ShellTab.scribe => const _NavSpec(
          Icons.mic_none_outlined,
          Icons.mic_none_outlined,
          'Scribe',
        ),
        ShellTab.rounds => const _NavSpec(
          Icons.medical_services_outlined,
          Icons.medical_services_outlined,
          'Rounds',
        ),
      },
  ];
  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: 8, bottom: bottom > 0 ? bottom : 10),
        child: Row(
          children: List<Widget>.generate(_items.length, (int index) {
            final _NavSpec item = _items[index];
            final bool selected = index == currentIndex;
            final Color color = selected ? colors.primary : colors.textMuted;
            return Expanded(
              child: InkWell(
                onTap: () => onItemSelected(index),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _BadgedIcon(
                      icon: selected ? item.selectedIcon : item.icon,
                      color: color,
                      badge: item.badge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: AppTypography.medium(
                        color: color,
                        fontSize: 11,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({required this.icon, required this.color, this.badge});

  final IconData icon;
  final Color color;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return SizedBox(
      width: 32,
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Icon(icon, color: color, size: 24),
          if (badge != null)
            Positioned(
              right: -6,
              top: -4,
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
                  style: TextStyle(
                    color: colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.selectedIcon, this.icon, this.label, {this.badge});

  final IconData selectedIcon;
  final IconData icon;
  final String label;
  final String? badge;
}
