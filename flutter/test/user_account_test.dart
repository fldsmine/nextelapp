import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/features/auth/domain/user_account.dart';

void main() {
  test('maps the legacy Kotlin profile field names and nested user response', () {
    final user = UserAccount.fromApi({
      'data': {
        'fullname': 'Ada Lovelace',
        'uname': 'ada_l',
        'email': 'ada@example.test',
        'userDP': 'https://cdn.example.test/ada.png',
        'status': 'active',
        'onboarding': {'email_verified': true},
      },
    });

    expect(user.name, 'Ada Lovelace');
    expect(user.username, 'ada_l');
    expect(user.email, 'ada@example.test');
    expect(user.avatarUrl, 'https://cdn.example.test/ada.png');
    expect(user.emailVerified, isTrue);
  });

  test('prefers the current API field names and tolerates a missing avatar', () {
    final user = UserAccount.fromApi({
      'full_name': 'Grace Hopper',
      'username': 'grace',
      'email': 'grace@example.test',
      'status': 'active',
      'email_verified_at': '2026-01-01T00:00:00Z',
    });

    expect(user.name, 'Grace Hopper');
    expect(user.username, 'grace');
    expect(user.avatarUrl, isEmpty);
    expect(user.emailVerified, isTrue);
  });
}
