import 'package:flutter/material.dart';
import 'package:round_ai/core/constants/app_constants.dart';
import 'package:round_ai/core/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  AppStorage(this._preferences, {SessionStore? session})
    : session = session ?? SessionStore.memory();

  final SharedPreferences _preferences;

  /// The session token. It lives in secure storage, not in preferences.
  final SessionStore session;

  Future<bool> saveString(String key, String value) {
    return _preferences.setString(key, value);
  }

  String? readString(String key) {
    return _preferences.getString(key);
  }

  Future<bool> remove(String key) {
    return _preferences.remove(key);
  }

  bool get hasAuthToken => session.hasToken;

  /// Earlier builds kept a demo token in preferences. Remove it.
  Future<void> purgeLegacyToken() async {
    await remove(AppConstants.authTokenKey);
  }

  String? get rememberedEmail {
    final String? value = readString(AppConstants.rememberedEmailKey);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  bool get rememberMeEnabled {
    return readString(AppConstants.rememberMeKey) == 'true';
  }

  String get clinicianName {
    final String? value = readString(AppConstants.clinicianNameKey);
    if (value == null || value.trim().isEmpty) return 'Clinician';
    return value.trim();
  }

  String? get selectedTeamId {
    final String? value = readString(AppConstants.selectedTeamIdKey);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  bool get hasSelectedTeam => selectedTeamId != null;

  /// Saved appearance. A new install follows the device theme.
  ThemeMode get themeMode {
    switch (readString(AppConstants.themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) {
    final String value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    };
    return saveString(AppConstants.themeModeKey, value);
  }

  /// Apple-friendly Remember Me: email only — never store the password.
  Future<void> saveRememberMe({required bool enabled, String? email}) async {
    await saveString(AppConstants.rememberMeKey, enabled ? 'true' : 'false');
    if (enabled) {
      final String trimmed = (email ?? rememberedEmail ?? '').trim();
      if (trimmed.isNotEmpty) {
        await saveString(AppConstants.rememberedEmailKey, trimmed);
      }
    } else {
      await remove(AppConstants.rememberedEmailKey);
    }
  }

  Future<void> saveSelectedTeam(String teamId) {
    return saveString(AppConstants.selectedTeamIdKey, teamId);
  }

  /// Clears the session. Keeps Remember Me email.
  Future<void> clearAuthSession() async {
    await session.clear();
    await remove(AppConstants.authTokenKey);
    await remove(AppConstants.clinicianNameKey);
    await remove(AppConstants.selectedTeamIdKey);
  }
}
