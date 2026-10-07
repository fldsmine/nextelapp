class Country {
  const Country({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
  });

  final String name;
  final String code;
  final String dialCode;
  final String flag;

  factory Country.fromServer(
    Map<String, Object?> json, {
    required Map<String, Country> dialCodeFallbacks,
  }) {
    final code = (json['code'] as String? ?? '').trim().toUpperCase();
    final local = dialCodeFallbacks[code];
    return Country(
      name: (json['name'] as String? ?? '').trim(),
      code: code,
      dialCode: (json['dial_code'] as String? ??
              json['dialCode'] as String? ??
              local?.dialCode ??
              '')
          .trim(),
      flag: (json['flag'] as String? ?? '').trim().isNotEmpty
          ? (json['flag'] as String).trim()
          : local?.flag ?? '',
    );
  }
}
