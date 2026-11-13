import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:round_ai/core/errors/result.dart';
import 'package:round_ai/core/router/app_routes.dart';
import 'package:round_ai/core/storage/app_storage.dart';
import 'package:round_ai/core/utils/app_log.dart';
import 'package:round_ai/features/chat/models/chat_push_payload.dart';
import 'package:round_ai/features/chat/repository/chat_repository.dart';
import 'package:round_ai/features/chat/services/chat_push_permission.dart';
import 'package:round_ai/features/chat/services/chat_push_token_source.dart';

typedef ChatPushNavigate = void Function(String path);
typedef ChatPushLoggedIn = bool Function();

/// Registers the device with `POST /chat/devices`, handles generic open taps,
/// and clears the local association on sign-out / 401.
///
/// Quiet hours / mute are intentionally not built (ask before adding).
class ChatPushController {
  ChatPushController({
    required ChatRepository chat,
    required AppStorage storage,
    required ChatPushTokenSource tokenSource,
    required ChatPushPermission permission,
    required ChatPushNavigate navigate,
    required ChatPushLoggedIn isLoggedIn,
    String? platform,
  }) : _chat = chat,
       _storage = storage,
       _tokens = tokenSource,
       _permission = permission,
       _navigate = navigate,
       _isLoggedIn = isLoggedIn,
       _platform = platform ?? _detectPlatform() {
    _tokenSub = _tokens.onTokenRefresh.listen((_) {
      unawaited(registerIfEnabled());
    });
  }

  static const String _optInKey = 'chat_push_opt_in';
  static const String _sessionRegisteredKey = 'chat_push_session_registered';

  final ChatRepository _chat;
  final AppStorage _storage;
  final ChatPushTokenSource _tokens;
  final ChatPushPermission _permission;
  final ChatPushNavigate _navigate;
  final ChatPushLoggedIn _isLoggedIn;
  final String _platform;

  StreamSubscription<String>? _tokenSub;
  String? _pendingChannelId;
  final ValueNotifier<bool> optInVisible = ValueNotifier<bool>(false);

  /// Opaque channel id waiting for a signed-in session.
  String? get pendingChannelId => _pendingChannelId;

  bool get hasOptedIn => _storage.readString(_optInKey) == 'accepted';

  bool get hasDismissedOptIn => _storage.readString(_optInKey) == 'dismissed';

  /// Soft prompt on the Chat tab (not at first launch).
  void refreshOptInVisibility({required bool chatEnabled}) {
    optInVisible.value =
        chatEnabled &&
        _isLoggedIn() &&
        !hasOptedIn &&
        !hasDismissedOptIn;
  }

  Future<void> dismissOptIn() async {
    await _storage.saveString(_optInKey, 'dismissed');
    optInVisible.value = false;
  }

  /// User accepted the in-app reason → OS permission → register.
  Future<bool> acceptOptInAndRegister() async {
    await _storage.saveString(_optInKey, 'accepted');
    optInVisible.value = false;
    final bool allowed = await _permission.request();
    if (!allowed) {
      AppLog.line('[chat_push] permission_denied');
      return false;
    }
    return registerIfEnabled();
  }

  /// Re-register when already opted in (sign-in / token refresh).
  Future<bool> registerIfEnabled() async {
    if (!hasOptedIn || !_isLoggedIn()) return false;
    final bool allowed = await _permission.isGranted;
    if (!allowed) return false;
    final String? token = await _tokens.currentToken();
    if (token == null || token.length < 8) return false;
    final Result<void> result = await _chat.registerDevice(
      platform: _platform,
      token: token,
    );
    if (result is Ok<void>) {
      await _storage.saveString(_sessionRegisteredKey, 'true');
      AppLog.line('[chat_push] registered platform=$_platform');
      return true;
    }
    AppLog.line('[chat_push] register_failed');
    return false;
  }

  /// Notification tap. Never reads message text. Auth first, then chat.
  void openFromNotification(ChatPushPayload payload) {
    final String? channelId = payload.channelId;
    if (!_isLoggedIn()) {
      _pendingChannelId = channelId;
      _navigate(AppRoutes.signIn);
      return;
    }
    _pendingChannelId = null;
    final String path = channelId == null || channelId.isEmpty
        ? AppRoutes.chat
        : AppRoutes.chatChannelPath(channelId);
    _navigate(path);
  }

  /// Call after splash / sign-in when the session is ready.
  void consumePendingOpen() {
    if (!_isLoggedIn()) return;
    final String? channelId = _pendingChannelId;
    _pendingChannelId = null;
    if (channelId == null || channelId.isEmpty) return;
    _navigate(AppRoutes.chatChannelPath(channelId));
  }

  /// Clears the local device association (backend stores hash only; no DELETE).
  Future<void> clear() async {
    _pendingChannelId = null;
    await _storage.remove(_sessionRegisteredKey);
    // Keep opt-in preference and install stub token; drop association only.
    AppLog.line('[chat_push] cleared');
  }

  void dispose() {
    unawaited(_tokenSub?.cancel() ?? Future<void>.value());
    optInVisible.dispose();
  }

  static String _detectPlatform() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => 'unknown',
    };
  }
}
