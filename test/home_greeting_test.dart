import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/features/today/models/home_greeting.dart';

void main() {
  test('greeting follows the local time ranges', () {
    expect(HomeGreeting.forTime(DateTime(2026, 11, 2, 4, 59)), 'Good evening');
    expect(HomeGreeting.forTime(DateTime(2026, 11, 2, 5)), 'Good morning');
    expect(HomeGreeting.forTime(DateTime(2026, 11, 2, 11, 59)), 'Good morning');
    expect(HomeGreeting.forTime(DateTime(2026, 11, 2, 12)), 'Good afternoon');
    expect(
      HomeGreeting.forTime(DateTime(2026, 11, 2, 16, 59)),
      'Good afternoon',
    );
    expect(HomeGreeting.forTime(DateTime(2026, 11, 2, 17)), 'Good evening');
  });

  test('date label uses the supplied day', () {
    expect(
      HomeGreeting.formatDate(DateTime(2026, 11, 2)),
      'Monday, November 2',
    );
  });
}
