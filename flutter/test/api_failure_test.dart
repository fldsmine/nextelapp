import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/core/errors/api_failure.dart';

void main() {
  test('returns the first server field message when present', () {
    const failure = ApiFailure(
      statusCode: 422,
      message: 'The submitted data is invalid.',
      fieldErrors: {
        'email': ['That email is already registered.', 'Use another email.'],
      },
    );

    expect(failure.firstFieldError('email'), 'That email is already registered.');
    expect(failure.firstFieldError('password'), isNull);
  });

  test('adds Retry-After guidance to rate-limit messages once', () {
    const failure = ApiFailure(
      statusCode: 429,
      message: 'Too many attempts.',
      retryAfterSeconds: 30,
    );
    const alreadyMentionsSeconds = ApiFailure(
      statusCode: 429,
      message: 'Try again in a few seconds.',
      retryAfterSeconds: 30,
    );

    expect(failure.displayMessage, 'Too many attempts. Please try again in 30 seconds.');
    expect(alreadyMentionsSeconds.displayMessage, 'Try again in a few seconds.');
  });
}
