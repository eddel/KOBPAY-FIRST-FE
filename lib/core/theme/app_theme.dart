import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

class AppTheme {
  static const Color ink = Color(0xFF111111);
  static const Color seed = Color(0xFF084198);
  static const Color accent = Color(0xFFF4A261);
  static const Color sand = Color(0xFFF7F4EF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color stone = Color(0xFFE6DED3);
  // Default palette: sand backgrounds with white surfaces.
  static const Color background = sand;
  static const Color surface = white;

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: seed,
      secondary: accent,
      surface: surface,
      background: background
    );

    final textTheme = GoogleFonts.spaceGroteskTextTheme().apply(
      bodyColor: ink,
      displayColor: ink
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: ink
        ),
        iconTheme: const IconThemeData(color: ink)
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: stone)
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: stone)
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: seed, width: 1.6)
        ),
        labelStyle: textTheme.labelLarge?.copyWith(color: ink.withOpacity(0.7))
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: stone)
        )
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white)
      )
    );
  }
}
