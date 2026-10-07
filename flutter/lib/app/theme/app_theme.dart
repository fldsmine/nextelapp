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

class NextelTheme {
  NextelTheme._();

  static ThemeData light({String fontFamily = 'Patrick'}) => _build(
        brightness: Brightness.light,
        primary: NextelPalette.primary,
        secondary: NextelPalette.accent,
        background: NextelPalette.background,
        surface: NextelPalette.surface,
        foreground: NextelPalette.text,
        fontFamily: fontFamily,
      );

  static ThemeData dark({String fontFamily = 'Patrick'}) => _build(
        brightness: Brightness.dark,
        primary: NextelPalette.authBlack,
        secondary: NextelPalette.authYellow,
        background: const Color(0xFF0B0B0B),
        surface: NextelPalette.authCard,
        foreground: Colors.white,
        fontFamily: fontFamily,
      );

  static ThemeData blue({String fontFamily = 'Patrick'}) => _build(
        brightness: Brightness.light,
        primary: NextelPalette.blue,
        secondary: const Color(0xFF42A5F5),
        background: const Color(0xFFF0F6FC),
        surface: Colors.white,
        foreground: const Color(0xFF162433),
        fontFamily: fontFamily,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color secondary,
    required Color background,
    required Color surface,
    required Color foreground,
    required String fontFamily,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: NextelPalette.danger,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: brightness == Brightness.dark
                ? Colors.white10
                : const Color(0x8CCACACA),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(
          color: brightness == Brightness.dark
              ? Colors.white54
              : NextelPalette.muted,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: brightness == Brightness.dark
                ? Colors.white24
                : NextelPalette.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: brightness == Brightness.dark
                ? Colors.white24
                : NextelPalette.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: NextelPalette.danger),
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
            bodyColor: foreground,
            displayColor: foreground,
          ),
      dividerColor: brightness == Brightness.dark
          ? Colors.white12
          : NextelPalette.border,
    );
  }
}
