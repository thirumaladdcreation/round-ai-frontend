import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/network/api_error.dart';
import 'package:round_ai/core/utils/date_format.dart';
import 'package:round_ai/core/utils/hospital_clock.dart';
import 'package:round_ai/core/utils/json_utils.dart';

void main() {
  tearDown(() {
    HospitalClock.timeZoneName = '';
  });

  test('HospitalClock todayIsoDate is yyyy-MM-dd', () {
    final String day = HospitalClock.todayIsoDate(
      () => DateTime(2026, 11, 12, 15, 30),
    );
    expect(day, '2026-11-12');
  });

  test('HospitalClock zoneLabel uses override when set', () {
    HospitalClock.timeZoneName = 'America/New_York';
    expect(HospitalClock.zoneLabel(), 'America/New_York');
  });

  test('Json.date keeps Zulu absolute and parses naive ISO', () {
    final DateTime? zulu = Json.date('2026-11-12T09:00:00Z');
    expect(zulu?.isUtc, isTrue);
    final DateTime? naive = Json.date('2026-11-12T09:00:00');
    expect(naive, isNotNull);
    expect(naive!.isUtc, isFalse);
  });

  test('dateTime includes a local timezone label', () {
    final String formatted = DateFormatter.dateTime(
      DateTime.utc(2026, 11, 12, 4, 6),
    );
    expect(formatted, contains('Nov'));
    expect(formatted, contains(','));
    // Zone name or UTC±HH:MM suffix after the clock.
    expect(
      RegExp(r'\d{2}:\d{2}\s+\S+').hasMatch(formatted),
      isTrue,
      reason: formatted,
    );
  });

  test('Safari permission codes map to clear web guidance', () {
    const ApiError denied = ApiError(
      code: 'permission_denied_web',
      message: '',
      status: 403,
    );
    expect(denied.kind, ApiErrorKind.permissionDenied);
    expect(denied.userMessage, contains('Safari'));
    expect(denied.userMessage, contains('Website Settings'));
  });

  test('HEIC guidance mentions iPhone Safari', () {
    const ApiError mime = ApiError(
      code: 'mime_not_allowed',
      message: '',
      status: 415,
    );
    expect(mime.userMessage, contains('iPhone Safari'));
  });
}
