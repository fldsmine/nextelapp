import 'country.dart';

class AuthValidation {
  AuthValidation._();

  static final RegExp _username = RegExp(r'^[A-Za-z0-9_-]{3,30}$');
  static final RegExp _email = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );
  static final RegExp _verificationCode = RegExp(r'^\d{6}$');

  static String? login(String value) =>
      value.trim().isEmpty ? 'Email or username is required' : null;

  static String? loginPassword(String value) =>
      value.isEmpty ? 'Password is required' : null;

  static Map<String, String> registration({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required String password,
    required bool acceptedTerms,
    required Country selectedCountry,
    required List<Country> availableCountries,
  }) {
    final errors = <String, String>{};
    final name = fullName.trim();
    if (name.isEmpty || name.length > 255) {
      errors['full_name'] = 'Enter your full name';
    }
    if (!_username.hasMatch(username.trim())) {
      errors['username'] =
          'Use 3–30 letters, numbers, underscores or hyphens';
    }
    if (!_email.hasMatch(email.trim())) {
      errors['email'] = 'Enter a valid email address';
    }
    final normalizedPhone = phoneForApi(phone, selectedCountry);
    if (normalizedPhone.isEmpty || normalizedPhone.length > 20) {
      errors['phone'] = 'Enter a phone number (up to 20 characters)';
    }
    if (password.length < 8) {
      errors['password'] = 'Password must contain at least 8 characters';
    }
    if (!acceptedTerms) errors['terms'] = 'Please accept the Terms & Conditions and Privacy Policy';
    if (!availableCountries.any((country) => country.code == selectedCountry.code)) {
      errors['country'] = 'Please select a supported country.';
    }
    return errors;
  }

  static String? resetEmail(String value) =>
      _email.hasMatch(value.trim()) ? null : 'Enter a valid email address';

  static String? verificationCode(String value) =>
      _verificationCode.hasMatch(value.trim())
          ? null
          : 'Enter the 6-digit code';

  static String? newPassword(String value) => value.length >= 8
      ? null
      : 'Password must contain at least 8 characters';

  static String phoneForApi(String input, Country country) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (input.trim().startsWith('+')) return '+$digits';
    if (digits.startsWith('00')) return '+${digits.substring(2)}';

    final dialDigits = country.dialCode.replaceAll(RegExp(r'\D'), '');
    if (dialDigits.isEmpty) return digits;
    if (digits.startsWith(dialDigits)) return '+$digits';
    return '+$dialDigits$digits';
  }
}
