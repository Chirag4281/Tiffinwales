import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFF66BB6A);
  static const Color gradientStart = Color(0xFF4CAF50);
  static const Color gradientEnd = Color(0xFF1B5E20);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    primaryColor: primaryGreen,
    colorScheme: const ColorScheme.light(
      primary: primaryGreen,
      secondary: lightGreen,
      surface: Colors.white,
    ),
    fontFamily: 'Poppins', // Add this font to pubspec.yaml
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}