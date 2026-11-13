import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// OS notification permission. Asked only after an in-app opt-in, never at
/// first launch.
abstract class ChatPushPermission {
  Future<bool> get isGranted;
  Future<bool> request();
}

class PermissionHandlerChatPushPermission implements ChatPushPermission {
  const PermissionHandlerChatPushPermission();

  @override
  Future<bool> get isGranted async {
    if (kIsWeb) return false;
    final PermissionStatus status = await Permission.notification.status;
    return status.isGranted;
  }

  @override
  Future<bool> request() async {
    if (kIsWeb) return false;
    final PermissionStatus status = await Permission.notification.request();
    return status.isGranted;
  }
}

/// Test double.
class FakeChatPushPermission implements ChatPushPermission {
  FakeChatPushPermission({this.granted = false});

  bool granted;

  @override
  Future<bool> get isGranted async => granted;

  @override
  Future<bool> request() async {
    granted = true;
    return true;
  }
}
