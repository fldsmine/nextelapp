class UserAccount {
  const UserAccount({
    required this.name,
    required this.email,
    required this.status,
    required this.emailVerified,
    this.username = '',
    this.avatarUrl = '',
  });

  final String name;
  final String username;
  final String email;
  final String status;
  final bool emailVerified;
  final String avatarUrl;

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
      name: _firstString(json, const ['full_name', 'fullname', 'name']),
      username: _firstString(json, const ['username', 'uname']),
      email: _firstString(json, const ['email']),
      status: _firstString(json, const ['status']),
      emailVerified: emailVerified,
      avatarUrl: _firstString(
        json,
        const ['userDP', 'user_dp', 'avatar_url', 'avatar'],
      ),
    );
  }

  static String _firstString(Map<String, Object?> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static Map<String, Object?> _asMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}
