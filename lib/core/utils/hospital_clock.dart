/// Clinical "today" and timestamp parsing helpers.
///
/// Hospital timezone is not confirmed yet (Prompt 8 §10). Until then:
/// - [timeZoneName] empty → device local zone
/// - When set (IANA or abbrev label), used for display labels only; wall-clock
///   "today" uses [demoClockIso] when DEMO_MODE is on, else the device clock.
class HospitalClock {
  HospitalClock._();

  /// Optional override from admin/hospital setting (e.g. `America/New_York`).
  /// Empty means "use device local".
  static String timeZoneName = const String.fromEnvironment(
    'HOSPITAL_TIMEZONE',
    defaultValue: '',
  );

  /// `--dart-define=DEMO_MODE=true` + `--dart-define=DEMO_CLOCK_ISO=...`
  /// mirrors backend DEMO_MODE / DEMO_CLOCK_ISO for scripted learning demos.
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE');
  static const String demoClockIso = String.fromEnvironment(
    'DEMO_CLOCK_ISO',
    defaultValue: '',
  );

  /// Runtime override (e.g. from `/health` demo_clock) — takes precedence when set.
  static String? runtimeDemoClockIso;

  static DateTime now([DateTime Function()? clock]) {
    if (clock != null) return clock();
    final DateTime? demo = _demoNow();
    return demo ?? DateTime.now();
  }

  static DateTime? _demoNow() {
    if (!demoMode && (runtimeDemoClockIso == null || runtimeDemoClockIso!.isEmpty)) {
      return null;
    }
    final String raw = (runtimeDemoClockIso?.trim().isNotEmpty == true)
        ? runtimeDemoClockIso!.trim()
        : demoClockIso.trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// `yyyy-MM-dd` for note_date / clinical day (demo clock when set).
  static String todayIsoDate([DateTime Function()? clock]) {
    final DateTime local = now(clock).toLocal();
    final String y = local.year.toString().padLeft(4, '0');
    final String m = local.month.toString().padLeft(2, '0');
    final String d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Label for UI (hospital override or device zone name).
  static String zoneLabel([DateTime? value]) {
    final String configured = timeZoneName.trim();
    if (configured.isNotEmpty) return configured;
    final DateTime local = (value ?? DateTime.now()).toLocal();
    final String name = local.timeZoneName.trim();
    if (name.isNotEmpty) return name;
    return 'local';
  }

  /// Parse API timestamps. Values with `Z`/offset stay absolute; **naive** ISO
  /// (no zone) is treated as hospital/local wall time (Dart local parse).
  static DateTime? parseApiTimestamp(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }
}
