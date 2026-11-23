import 'package:round_ai/core/utils/hospital_clock.dart';

/// Small date helpers, so no extra package is needed.
class DateFormatter {
  const DateFormatter._();

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Zone label for UI (hospital override via [HospitalClock], else device).
  static String localTimezoneLabel([DateTime? value]) {
    final String hospital = HospitalClock.zoneLabel(value);
    if (HospitalClock.timeZoneName.trim().isNotEmpty) return hospital;
    final DateTime local = (value ?? DateTime.now()).toLocal();
    final String name = local.timeZoneName.trim();
    if (name.isNotEmpty && name != 'UTC') return name;
    final Duration offset = local.timeZoneOffset;
    final String sign = offset.isNegative ? '-' : '+';
    final int hours = offset.inHours.abs();
    final int mins = offset.inMinutes.abs() % 60;
    return 'UTC$sign${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  /// `Nov 12, 09:36 IST` — local clock with timezone so Safari/demo clocks stay clear.
  static String dateTime(DateTime value, {bool withZone = true}) {
    final DateTime local = value.toLocal();
    final String hh = local.hour.toString().padLeft(2, '0');
    final String mm = local.minute.toString().padLeft(2, '0');
    final String base = '${_months[local.month - 1]} ${local.day}, $hh:$mm';
    return withZone ? '$base ${localTimezoneLabel(local)}' : base;
  }

  /// `Nov 12, 2026`. For dates that carry no time of day.
  static String date(DateTime value) {
    final DateTime local = value.toLocal();
    return '${_months[local.month - 1]} ${local.day}, ${local.year}';
  }

  /// A missing time is shown as Unknown, never guessed.
  static String dateTimeOrUnknown(DateTime? value, {bool withZone = true}) {
    return value == null ? 'Time unknown' : dateTime(value, withZone: withZone);
  }
}
