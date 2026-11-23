class AppConstants {
  const AppConstants._();

  static const String appName = 'RoundsAI';
  /// Fly trial / free machines cold-start can exceed 15s; keep headroom.
  static const Duration connectTimeout = Duration(seconds: 45);
  static const Duration receiveTimeout = Duration(seconds: 45);

  /// AI calls are synchronous on the backend and can take about a minute.
  static const Duration aiReceiveTimeout = Duration(seconds: 90);

  /// Uploads of audio/images: long send + receive (transcribe / vision).
  static const Duration uploadTimeout = Duration(seconds: 120);

  /// Key inside secure storage. The token is never kept in shared_preferences.
  static const String authTokenKey = 'auth_token';
  static const String rememberMeKey = 'remember_me';
  static const String rememberedEmailKey = 'remembered_email';
  static const String clinicianNameKey = 'clinician_name';
  static const String selectedTeamIdKey = 'selected_team_id';
  static const String themeModeKey = 'theme_mode';

  /// In-progress note compose text keyed as `note_compose_<patientId>`.
  static const String noteComposeKeyPrefix = 'note_compose_';
}
