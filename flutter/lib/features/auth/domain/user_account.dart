class UserAccount {
  const UserAccount({
    required this.name,
    required this.email,
    required this.status,
    required this.emailVerified,
    this.username = '',
  });

  final String name;
  final String username;
  final String email;
  final String status;
  final bool emailVerified;

  bool get isSuspended =>
      const {'suspended', 'banned', 'blocked'}.contains(status.toLowerCase());

  factory UserAccount.fromApi(Object? value) {
    var json = _asMap(value);
    final nestedData = json['data'];
    if (nestedData is Map) json = _asMap(nestedData);

    final onboarding = _asMap(json['onboarding']);
    final verifiedValue = onboarding['email_verified'];
    final emailVerified = verifiedValue is bool
        ? verifiedValue
        : (json['email_verified_at']?.toString().isNotEmpty ?? false);

    return UserAccount(
      name: (json['full_name'] as String? ?? json['name'] as String? ?? '').trim(),
      username: (json['username'] as String? ?? '').trim(),
      email: (json['email'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      emailVerified: emailVerified,
    );
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}
