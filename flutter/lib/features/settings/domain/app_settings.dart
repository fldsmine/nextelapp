class AppSettings {
  const AppSettings({
    this.notificationsEnabled = true,
    this.notificationSound = true,
    this.notificationVibration = false,
    this.dailyReminder = false,
    this.biometricEnabled = false,
    this.theme = 'Light',
    this.fontFamily = 'Patrick',
    this.fontScale = 1.0,
  });

  static const List<String> themes = ['Light', 'Dark', 'Blue'];
  static const List<String> fontFamilies = [
    'Poppins',
    'Roboto',
    'Nunito',
    'Patrick',
    'Montserrat',
  ];
  static const double minFontScale = .75;
  static const double maxFontScale = 2.5;

  final bool notificationsEnabled;
  final bool notificationSound;
  final bool notificationVibration;
  final bool dailyReminder;
  final bool biometricEnabled;
  final String theme;
  final String fontFamily;
  final double fontScale;

  factory AppSettings.fromMap(Map<String, Object?> values) {
    final rawFontScale = values['fontScale'];
    final fontScale = rawFontScale is num && rawFontScale.isFinite
        ? rawFontScale.toDouble()
        : 1.0;
    return AppSettings(
      notificationsEnabled: _boolValue(values['notifications_enabled'], true),
      notificationSound: _boolValue(values['sound'], true),
      notificationVibration: _boolValue(values['vibration'], false),
      dailyReminder: _boolValue(values['daily_reminder'], false),
      biometricEnabled: _boolValue(values['xbg_biometric_enabled'], false),
      theme: _choice(values['theme'], themes, 'Light'),
      fontFamily: _choice(values['fontFamily'], fontFamilies, 'Patrick'),
      fontScale: fontScale.clamp(minFontScale, maxFontScale).toDouble(),
    );
  }

  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? notificationSound,
    bool? notificationVibration,
    bool? dailyReminder,
    bool? biometricEnabled,
    String? theme,
    String? fontFamily,
    double? fontScale,
  }) =>
      AppSettings(
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        notificationSound: notificationSound ?? this.notificationSound,
        notificationVibration:
            notificationVibration ?? this.notificationVibration,
        dailyReminder: dailyReminder ?? this.dailyReminder,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        theme: theme ?? this.theme,
        fontFamily: fontFamily ?? this.fontFamily,
        fontScale: fontScale ?? this.fontScale,
      );

  static bool _boolValue(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  static String _choice(Object? value, List<String> choices, String fallback) {
    if (value is! String) return fallback;
    for (final choice in choices) {
      if (choice.toLowerCase() == value.toLowerCase()) return choice;
    }
    return fallback;
  }
}
