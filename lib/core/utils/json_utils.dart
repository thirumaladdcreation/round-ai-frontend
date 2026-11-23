/// Small readers for backend JSON. They never throw on a missing or oddly
/// typed field: a missing value becomes null or the given fallback.
class Json {
  const Json._();

  static Map<String, dynamic> map(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> maps(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// A list that arrives either bare (`[...]`) or wrapped (`{"key": [...]}`).
  static List<Map<String, dynamic>> itemsOf(Object? body, String key) {
    if (body is List) return maps(body);
    if (body is Map) return maps(body[key]);
    return const <Map<String, dynamic>>[];
  }

  /// First non-empty value among [keys].
  static String firstString(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final String? value = stringOrNull(json[key]);
      if (value != null) return value;
    }
    return '';
  }

  static String string(Object? value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }

  static String? stringOrNull(Object? value) {
    if (value == null) return null;
    final String text = value.toString();
    return text.isEmpty ? null : text;
  }

  static List<String> strings(Object? value) {
    if (value is! List) return const <String>[];
    return value.map((Object? e) => e.toString()).toList();
  }

  static int integer(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? integerOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool boolean(Object? value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }

  /// Parses API timestamps. Prefer ISO with offset/`Z`. Naive ISO (no zone) is
  /// treated as hospital/local wall time — see [HospitalClock.parseApiTimestamp].
  static DateTime? date(Object? value) {
    if (value == null) return null;
    // Inline tryParse keeps json_utils free of Flutter-only imports in tests;
    // HospitalClock documents the naive-vs-offset contract used app-wide.
    return DateTime.tryParse(value.toString());
  }
}
