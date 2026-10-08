import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/features/auth/domain/auth_validation.dart';
import 'package:nextel_connect/features/auth/domain/country.dart';

void main() {
  const nigeria = Country(
    name: 'Nigeria',
    code: 'NG',
    dialCode: '+234',
    flag: '🇳🇬',
  );

  group('login and reset validation', () {
    test('requires a login and password without trimming password content', () {
      expect(AuthValidation.login('  '), isNotNull);
      expect(AuthValidation.login(' user@example.com '), isNull);
      expect(AuthValidation.loginPassword(''), isNotNull);
      expect(AuthValidation.loginPassword('  '), isNull);
    });

    test('requires valid reset email and six-digit code', () {
      expect(AuthValidation.resetEmail('user@example.com'), isNull);
      expect(AuthValidation.resetEmail('not-an-email'), isNotNull);
      expect(AuthValidation.verificationCode('012345'), isNull);
      expect(AuthValidation.verificationCode('12345'), isNotNull);
      expect(AuthValidation.verificationCode('12a456'), isNotNull);
    });
  });

  group('registration validation', () {
    test('preserves server field names and requires country/legal consent', () {
      final errors = AuthValidation.registration(
        fullName: '',
        username: 'x',
        email: 'invalid',
        phone: '',
        password: 'short',
        acceptedTerms: false,
        selectedCountry: nigeria,
        availableCountries: const [],
      );

      expect(errors.keys, containsAll([
        'full_name',
        'username',
        'email',
        'phone',
        'password',
        'terms',
        'country',
      ]));
    });

    test('normalizes local and international phone numbers as the Android app', () {
      expect(AuthValidation.phoneForApi('080 1234 5678', nigeria),
          '+23408012345678');
      expect(AuthValidation.phoneForApi('+44 20 1234 5678', nigeria),
          '+442012345678');
      expect(AuthValidation.phoneForApi('0044 20 1234 5678', nigeria),
          '+442012345678');
    });
  });
}
