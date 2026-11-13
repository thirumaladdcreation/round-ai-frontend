import 'dart:async';
import 'dart:math';

import 'package:round_ai/core/storage/app_storage.dart';

/// Supplies a device push token. Swap in an FCM/APNs adapter once the
/// provider + BAA are confirmed — do not embed vendor SDKs here yet.
abstract class ChatPushTokenSource {
  Future<String?> currentToken();

  Stream<String> get onTokenRefresh;

  /// Drops any locally cached token association for this install.
  Future<void> clearLocal();
}

/// Dev/demo token. Stable per install; never logs the value.
class StubChatPushTokenSource implements ChatPushTokenSource {
  StubChatPushTokenSource({required AppStorage storage, Random? random})
    : _storage = storage,
      _random = random ?? Random.secure();

  static const String _tokenKey = 'chat_push_stub_token';

  final AppStorage _storage;
  final Random _random;
  final StreamController<String> _refresh =
      StreamController<String>.broadcast();

  @override
  Stream<String> get onTokenRefresh => _refresh.stream;

  @override
  Future<String?> currentToken() async {
    final String? existing = _storage.readString(_tokenKey);
    if (existing != null && existing.length >= 8) return existing;
    final String next =
        'stub-${List<int>.generate(16, (_) => _random.nextInt(256)).map((int b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    await _storage.saveString(_tokenKey, next);
    return next;
  }

  @override
  Future<void> clearLocal() async {
    await _storage.remove(_tokenKey);
  }

  void dispose() {
    unawaited(_refresh.close());
  }
}
