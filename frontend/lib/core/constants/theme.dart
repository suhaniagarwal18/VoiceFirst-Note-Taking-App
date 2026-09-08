import 'package:flutter/material.dart';

class AccessibleTheme {
  // WCAG AAA Compliant High-Contrast Palette
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceElevated = Color(0xFF2C2C2C);
  
  static const Color primaryGold = Color(0xFFFFD700);      // High-contrast primary
  static const Color accentBlue = Color(0xFF64B5F6);       // Secondary indicator
  static const Color textWhite = Color(0xFFFFFFFF);        // Primary text
  static const Color textSubdued = Color(0xFFE0E0E0);      // Secondary text
  static const Color successGreen = Color(0xFF81C784);     // Confirmation
  static const Color errorRed = Color(0xFFFF6B6B);         // High contrast error
  static const Color focusRing = Color(0xFFFFEB3B);        // Keyboard/accessibility focus ring

  // Tag Colors with high contrast
  static const Color tagDefinition = Color(0xFF4FC3F7);   // Cyan/Light Blue
  static const Color tagExample = Color(0xFF81C784);      // Green
  static const Color tagImportant = Color(0xFFFFD700);    // Gold
  static const Color tagGeneral = Color(0xFFB0BEC5);      // Light Grey

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryGold,
      colorScheme: const ColorScheme.dark(
        primary: primaryGold,
        onPrimary: Colors.black,
        secondary: accentBlue,
        onSecondary: Colors.black,
        surface: surface,
        onSurface: textWhite,
        error: errorRed,
        onError: Colors.black,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textWhite, height: 1.2),
        displayMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textWhite, height: 1.25),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: primaryGold),
        titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textWhite),
        bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.normal, color: textWhite, height: 1.4),
        bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: textSubdued, height: 1.4),
        labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: Colors.black,
          minimumSize: const Size(88, 56), // Minimum 56dp for accessible tap target
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white, width: 2),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textWhite,
          minimumSize: const Size(88, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          side: const BorderSide(color: primaryGold, width: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF444444), width: 1.5),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
    );
  }
}
