import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:round_ai/core/config/app_environment.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/features/authentication/models/app_user.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/chat/chat_unread_badge.dart';
import 'package:round_ai/features/chat/widgets/chat_realtime_binder.dart';
import 'package:round_ai/features/patient/data/patient_workspace.dart';
import 'package:round_ai/shared/widgets/ai_disabled_banner.dart';
import 'package:round_ai/shared/widgets/app_bottom_nav_bar.dart';
import 'package:round_ai/shared/widgets/app_menu_drawer.dart';

class MainShell extends StatelessWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  String? _openTaskBadge() {
    // The badge counts the demo board. On the backend there is no cheap
    // team-wide count, so none is shown.
    if (!AppEnvironment.useDemo) return null;
    final int pending = allDemoTasks
        .where((ChartTask task) => !DemoTaskBoard.isDone(task.id))
        .length;
    if (pending == 0) return null;
    return '$pending';
  }

  void _onItemSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double keyboard = media.viewInsets.bottom;
    final double navHeight = 64 + media.padding.bottom;
    final double insetAboveNav = keyboard > navHeight
        ? keyboard - navHeight
        : 0;

    final ProfileRepository profile =
        InjectionContainer.instance.profileRepository;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: ChatRealtimeBinder(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          drawer: const AppMenuDrawer(),
          drawerEnableOpenDragGesture: true,
          body: Column(
            children: <Widget>[
              ValueListenableBuilder<MeProfile?>(
                valueListenable: profile.changes,
                builder: (BuildContext context, MeProfile? me, Widget? child) {
                  // The banner takes the status bar space, so the screen below
                  // must not add it again.
                  final bool aiOff = profile.aiOff;
                  return Expanded(
                    child: Column(
                      children: <Widget>[
                        if (aiOff) const AiDisabledBanner(),
                        Expanded(
                          child: MediaQuery(
                            data: media.copyWith(
                              viewInsets: media.viewInsets.copyWith(
                                bottom: insetAboveNav,
                              ),
                              padding: aiOff
                                  ? media.padding.copyWith(top: 0)
                                  : media.padding,
                            ),
                            child: navigationShell,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _ShellBottomBar(
                currentIndex: navigationShell.currentIndex,
                onItemSelected: _onItemSelected,
                openTaskBadge: _openTaskBadge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellBottomBar extends StatelessWidget {
  const _ShellBottomBar({
    required this.currentIndex,
    required this.onItemSelected,
    required this.openTaskBadge,
  });

  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final String? Function() openTaskBadge;

  @override
  Widget build(BuildContext context) {
    final ChatUnreadBadge chatBadge =
        InjectionContainer.instance.chatUnreadBadge;

    Widget bar({String? tasks, String? chat}) {
      return AppBottomNavBar(
        currentIndex: currentIndex,
        onItemSelected: onItemSelected,
        tasksBadge: tasks,
        chatBadge: AppFeatures.chat ? chat : null,
      );
    }

    if (AppEnvironment.useDemo) {
      return ValueListenableBuilder<int>(
        valueListenable: DemoTaskBoard.changes,
        builder: (BuildContext context, int _, Widget? child) {
          return ValueListenableBuilder<int>(
            valueListenable: chatBadge,
            builder: (BuildContext context, int unread, Widget? child) {
              return bar(
                tasks: openTaskBadge(),
                chat: chatBadge.label,
              );
            },
          );
        },
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: chatBadge,
      builder: (BuildContext context, int unread, Widget? child) {
        return bar(chat: chatBadge.label);
      },
    );
  }
}
