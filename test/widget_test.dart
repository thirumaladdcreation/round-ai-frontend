import 'package:flutter_test/flutter_test.dart';
import 'package:round_ai/core/errors/failures.dart';
import 'package:round_ai/core/errors/result.dart';

void main() {
  test('Result.when returns the success value', () {
    const Result<int> result = Ok<int>(2);
    expect(result.when(ok: (int value) => value, err: (_) => -1), 2);
  });

  test('Result.when returns the failure message', () {
    const Result<int> result = Err<int>(ValidationFailure('missing'));
    expect(
      result.when(
        ok: (int value) => '$value',
        err: (Failure failure) => failure.message,
      ),
      'missing',
    );
  });
}
