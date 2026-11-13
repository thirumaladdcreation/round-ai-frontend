/// Time-based greeting. Evening covers 5 PM through 4:59 AM.
class HomeGreeting {
  const HomeGreeting._();

  static String forTime(DateTime time) {
    final int hour = time.hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String formatDate(DateTime time) {
    const List<String> weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final String weekday = weekdays[time.weekday - 1];
    final String month = months[time.month - 1];
    return '$weekday, $month ${time.day}';
  }
}
