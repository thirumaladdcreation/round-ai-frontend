import 'dart:math';

/// Idempotency-Key values for AI POSTs.
///
/// Create one key per user action and reuse it when that action is retried,
/// so a retry never produces a second generation:
///
/// ```dart
/// final String key = IdempotencyKey.create();   // when the user taps
/// await client.postAi(path, data: body, idempotencyKey: key);
/// // Retry button: call postAi again with the same [key].
/// ```
class IdempotencyKey {
  const IdempotencyKey._();

  static const String header = 'Idempotency-Key';

  static final Random _random = Random.secure();

  /// A random version 4 UUID.
  static String create() {
    final List<int> b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String hex(int from, int to) => b
        .sublist(from, to)
        .map((int v) => v.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}
