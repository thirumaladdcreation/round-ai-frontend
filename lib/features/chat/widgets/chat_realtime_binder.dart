import 'package:flutter/material.dart';
import 'package:round_ai/core/config/app_features.dart';
import 'package:round_ai/core/di/injection_container.dart';
import 'package:round_ai/features/authentication/models/app_user.dart';
import 'package:round_ai/features/authentication/repository/profile_repository.dart';
import 'package:round_ai/features/chat/services/chat_push_controller.dart';
import 'package:round_ai/features/chat/services/chat_realtime_controller.dart';

/// Keeps chat SSE in sync with auth + app lifecycle. Mount inside the shell
/// after sign-in. Disconnects when backgrounded; reconnects on resume.
class ChatRealtimeBinder extends StatefulWidget {
  const ChatRealtimeBinder({required this.child, super.key});

  final Widget child;

  @override
  State<ChatRealtimeBinder> createState() => _ChatRealtimeBinderState();
}

class _ChatRealtimeBinderState extends State<ChatRealtimeBinder>
    with WidgetsBindingObserver {
  ChatRealtimeController get _rt =>
      InjectionContainer.instance.chatRealtime;

  ChatPushController get _push => InjectionContainer.instance.chatPush;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final ProfileRepository profile =
        InjectionContainer.instance.profileRepository;
    profile.changes.addListener(_onProfile);
    _bootstrap();
  }

  @override
  void dispose() {
    InjectionContainer.instance.profileRepository.changes.removeListener(
      _onProfile,
    );
    WidgetsBinding.instance.removeObserver(this);
    _rt.stop();
    super.dispose();
  }

  void _bootstrap() {
    if (!AppFeatures.chat) return;
    final InjectionContainer di = InjectionContainer.instance;
    final MeProfile? me = di.profileRepository.current;
    _rt.setCurrentUserId(me?.user.id);
    _rt.setSignedIn(di.isLoggedIn && (me?.chatEnabled ?? true));
    final AppLifecycleState state =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      _rt.onForeground();
    } else {
      _rt.onBackground();
    }
    if (di.isLoggedIn) {
      _rt.start();
      _push.consumePendingOpen();
      _push.registerIfEnabled();
    }
  }

  void _onProfile() {
    final InjectionContainer di = InjectionContainer.instance;
    final MeProfile? me = di.profileRepository.current;
    _rt.setCurrentUserId(me?.user.id);
    final bool chatOk = me == null || me.chatEnabled;
    _rt.setSignedIn(di.isLoggedIn && chatOk);
    if (di.isLoggedIn && chatOk) {
      _rt.start();
      _push.consumePendingOpen();
      _push.registerIfEnabled();
    } else {
      _rt.stop(clearCursor: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!AppFeatures.chat) return;
    if (state == AppLifecycleState.resumed) {
      _rt.onForeground();
      if (InjectionContainer.instance.isLoggedIn) {
        _rt.start();
        _push.consumePendingOpen();
      }
    } else {
      // inactive / paused / hidden / detached — drop the stream.
      _rt.onBackground();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
