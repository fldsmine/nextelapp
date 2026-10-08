import 'package:flutter/material.dart';

/// The isolated dark theme used by the uploaded games, without fetching fonts
/// at runtime. The host app already bundles Poppins as a local asset.
class AppTheme {
  AppTheme._();

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0B0F1A),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2D4B2F),
      brightness: Brightness.dark,
      surface: const Color(0xFF111827),
    ),
    textTheme: ThemeData(brightness: Brightness.dark, fontFamily: 'Poppins')
        .textTheme
        .apply(bodyColor: Colors.white, displayColor: Colors.white),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
  );
}
