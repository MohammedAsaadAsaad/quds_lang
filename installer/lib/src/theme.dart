import 'package:material_ui/material_ui.dart';

/// Refined, low-noise design tokens for the Quds Desktop Installer.
class QudsPalette {
  static const fontUi = 'IBMPlexSansArabic';
  static const fontMono = 'JetBrainsMono';

  // Calm dark surfaces
  static const darkCanvas = Color(0xFF0A0F1A);
  static const darkSidebar = Color(0xFF0E1525);
  static const darkSurface = Color(0xFF121B2E);
  static const darkConsole = Color(0xFF070B14);
  static const darkBorder = Color(0xFF1E2A42);

  // Calm light surfaces
  static const lightCanvas = Color(0xFFF8FAFC);
  static const lightSidebar = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE2E8F0);

  // Brand accents (used with restraint)
  static const royalBlue = Color(0xFF1D6FD8);
  static const deepBlue = Color(0xFF0F4C81);
  static const domeGold = Color(0xFFF2B71D);
  static const warmGold = Color(0xFFFAD161);

  // Semantic accents
  static const okGreen = Color(0xFF22C55E);
  static const warnAmber = Color(0xFFF59E0B);
  static const errRed = Color(0xFFEF4444);

  // Text hierarchy
  static const darkTextPrimary = Color(0xFFF1F5F9);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkTextMuted = Color(0xFF64748B);

  static const lightTextPrimary = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF475569);
  static const lightTextMuted = Color(0xFF94A3B8);

  static ThemeData darkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: royalBlue,
      brightness: Brightness.dark,
      primary: domeGold,
      secondary: royalBlue,
      surface: darkSurface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontUi,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkCanvas,
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: domeGold,
          foregroundColor: darkCanvas,
          textStyle: const TextStyle(
            fontFamily: fontUi,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: const BorderSide(color: darkBorder),
          textStyle: const TextStyle(
            fontFamily: fontUi,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: fontUi,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData lightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: deepBlue,
      brightness: Brightness.light,
      primary: deepBlue,
      secondary: domeGold,
      surface: lightSurface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontUi,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightCanvas,
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: deepBlue,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: fontUi,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightTextPrimary,
          side: const BorderSide(color: lightBorder),
          textStyle: const TextStyle(
            fontFamily: fontUi,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(
            fontFamily: fontUi,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
