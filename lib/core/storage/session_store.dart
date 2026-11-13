import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:round_ai/core/constants/app_constants.dart';

/// Where the session token lives between app launches.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Keychain on iOS, Keystore-backed storage on Android.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Default resetOnError=true wipes the token on a flaky Keystore
            // read (common on some Android OEMs). That looks like a sudden
            // sign-out after leaving the app. Keep the entry and treat a
            // failed read as signed-out for this launch only.
            aOptions: AndroidOptions(resetOnError: false),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: AppConstants.authTokenKey);
    } on PlatformException {
      // Unreadable or corrupt entry. Treat it as signed out.
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> write(String token) {
    return _storage.write(key: AppConstants.authTokenKey, value: token);
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: AppConstants.authTokenKey);
    } on PlatformException {
      // Nothing left to delete.
    } on MissingPluginException {
      // No plugin, so nothing was stored.
    }
  }
}

/// Keeps the token in memory only. Used by tests and by USE_DEMO runs.
class MemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

/// The signed-in session. Reads are synchronous so the router and the
/// interceptor never wait on disk.
///
/// With `persist: false` (Remember me off) the token stays in memory and
/// is gone when the app closes.
class SessionStore {
  SessionStore(this._store);

  /// In-memory only. Handy default for tests.
  SessionStore.memory() : _store = MemoryTokenStore();

  final TokenStore _store;
  String? _token;

  /// Loads a token saved by an earlier launch.
  Future<void> restore() async {
    final String? saved = await _store.read();
    _token = (saved == null || saved.isEmpty) ? null : saved;
  }

  String? get token => _token;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Future<void> save(String token, {required bool persist}) async {
    _token = token;
    if (persist) {
      await _store.write(token);
    } else {
      await _store.clear();
    }
  }

  Future<void> clear() async {
    _token = null;
    await _store.clear();
  }
}
