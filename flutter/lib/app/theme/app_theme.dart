import 'package:flutter/material.dart';

class NextelPalette {
  NextelPalette._();

  static const Color primary = Color(0xFF18443E);
  static const Color primaryLight = Color(0xFF48948A);
  static const Color accent = Color(0xFFDCEB6A);
  static const Color background = Color(0xFFF4F1EA);
  static const Color surface = Color(0xFFFAF9F8);
  static const Color text = Color(0xFF1A1A1A);
  static const Color muted = Color(0xFF8C8C8C);
  static const Color border = Color(0xFFCACACA);
  static const Color danger = Color(0xFFFF3B30);
  static const Color authBlack = Color(0xFF050505);
  static const Color authCard = Color(0xFF101010);
  static const Color authInput = Color(0xFF171717);
  static const Color authYellow = Color(0xFFF6C945);
  static const Color blue = Color(0xFF1565C0);
}

@immutable
class NextelColors extends ThemeExtension<NextelColors> {
  const NextelColors({
    required this.primary,
    required this.primaryLight,
    required this.accent,
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.border,
    required this.danger,
    required this.authBlack,
    required this.authCard,
    required this.authInput,
    required this.authYellow,
    required this.blue,
  });

  static const light = NextelColors(
    primary: NextelPalette.primary,
    primaryLight: NextelPalette.primaryLight,
    accent: NextelPalette.accent,
    background: NextelPalette.background,
    surface: NextelPalette.surface,
    text: NextelPalette.text,
    muted: NextelPalette.muted,
    border: NextelPalette.border,
    danger: NextelPalette.danger,
    authBlack: NextelPalette.authBlack,
    authCard: NextelPalette.authCard,
    authInput: NextelPalette.authInput,
    authYellow: NextelPalette.authYellow,
    blue: NextelPalette.blue,
  );

  static const dark = NextelColors(
    primary: Color(0xFF050505),
    primaryLight: Color(0xFF424242),
    accent: Color(0xFFF6C945),
    background: Color(0xFF0B0B0B),
    surface: Color(0xFF101010),
    text: Colors.white,
    muted: Color(0xFFB0B0B0),
    border: Color(0xFF3A3A3A),
    danger: Color(0xFFFF6B6B),
    authBlack: NextelPalette.authBlack,
    authCard: NextelPalette.authCard,
    authInput: NextelPalette.authInput,
    authYellow: NextelPalette.authYellow,
    blue: NextelPalette.blue,
  );

  static const blueTheme = NextelColors(
    primary: NextelPalette.blue,
    primaryLight: Color(0xFF42A5F5),
    accent: Color(0xFF42A5F5),
    background: Color(0xFFF0F6FC),
    surface: Colors.white,
    text: Color(0xFF162433),
    muted: Color(0xFF607080),
    border: Color(0xFFCAD6E2),
    danger: NextelPalette.danger,
    authBlack: NextelPalette.authBlack,
    authCard: NextelPalette.authCard,
    authInput: NextelPalette.authInput,
    authYellow: NextelPalette.authYellow,
    blue: NextelPalette.blue,
  );

  final Color primary;
  final Color primaryLight;
  final Color accent;
  final Color background;
  final Color surface;
  final Color text;
  final Color muted;
  final Color border;
  final Color danger;
  final Color authBlack;
  final Color authCard;
  final Color authInput;
  final Color authYellow;
  final Color blue;

  @override
  NextelColors copyWith({
    Color? primary,
    Color? primaryLight,
    Color? accent,
    Color? background,
    Color? surface,
    Color? text,
    Color? muted,
    Color? border,
    Color? danger,
    Color? authBlack,
    Color? authCard,
    Color? authInput,
    Color? authYellow,
    Color? blue,
  }) =>
      NextelColors(
        primary: primary ?? this.primary,
        primaryLight: primaryLight ?? this.primaryLight,
        accent: accent ?? this.accent,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        text: text ?? this.text,
        muted: muted ?? this.muted,
        border: border ?? this.border,
        danger: danger ?? this.danger,
        authBlack: authBlack ?? this.authBlack,
        authCard: authCard ?? this.authCard,
        authInput: authInput ?? this.authInput,
        authYellow: authYellow ?? this.authYellow,
        blue: blue ?? this.blue,
      );

  @override
  NextelColors lerp(ThemeExtension<NextelColors>? other, double t) {
    if (other is! NextelColors) return this;
    return NextelColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      authBlack: Color.lerp(authBlack, other.authBlack, t)!,
      authCard: Color.lerp(authCard, other.authCard, t)!,
      authInput: Color.lerp(authInput, other.authInput, t)!,
      authYellow: Color.lerp(authYellow, other.authYellow, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
    );
  }
}

extension NextelBuildContextColors on BuildContext {
  NextelColors get nextelColors =>
      Theme.of(this).extension<NextelColors>() ?? NextelColors.light;
}

class NextelTheme {
  NextelTheme._();

  static ThemeData light({String fontFamily = 'Patrick'}) => _build(
        brightness: Brightness.light,
        colors: NextelColors.light,
        fontFamily: fontFamily,
      );

  static ThemeData dark({String fontFamily = 'Patrick'}) => _build(
        brightness: Brightness.dark,
        colors: NextelColors.dark,
        fontFamily: fontFamily,
      );

  static ThemeData blue({String fontFamily = 'Patrick'}) => _build(
        brightness: Brightness.light,
        colors: NextelColors.blueTheme,
        fontFamily: fontFamily,
      );

  static ThemeData _build({
    required Brightness brightness,
    required NextelColors colors,
    required String fontFamily,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: brightness,
      primary: colors.primary,
      secondary: colors.accent,
      surface: colors.surface,
      error: colors.danger,
      onPrimary: Colors.white,
      onSurface: colors.text,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      fontFamily: fontFamily,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.border.withValues(alpha: .55)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        hintStyle: TextStyle(color: colors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: colors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
      textTheme: ThemeData(
        brightness: brightness,
        fontFamily: fontFamily,
      ).textTheme.apply(
            bodyColor: colors.text,
            displayColor: colors.text,
          ),
      dividerColor: colors.border,
    );
  }
}
