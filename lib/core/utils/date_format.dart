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

  /// `Nov 12, 09:36` in the device's local time.
  static String dateTime(DateTime value) {
    final DateTime local = value.toLocal();
    final String hh = local.hour.toString().padLeft(2, '0');
    final String mm = local.minute.toString().padLeft(2, '0');
    return '${_months[local.month - 1]} ${local.day}, $hh:$mm';
  }

  /// `Nov 12, 2026`. For dates that carry no time of day.
  static String date(DateTime value) {
    final DateTime local = value.toLocal();
    return '${_months[local.month - 1]} ${local.day}, ${local.year}';
  }

  /// A missing time is shown as Unknown, never guessed.
  static String dateTimeOrUnknown(DateTime? value) {
    return value == null ? 'Time unknown' : dateTime(value);
  }
}
