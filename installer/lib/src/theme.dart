import 'package:material_ui/material_ui.dart';

/// Brand palette derived directly from the official Quds logo
/// (Deep Royal Blue + Dome Gold + Ice White).
class QudsPalette {
  static const midnightBg = Color(0xFF071122);
  static const midnightSurface = Color(0xFF0E1C36);
  static const midnightCard = Color(0xFF132546);
  static const midnightBorder = Color(0xFF213A66);

  static const royalBlue = Color(0xFF0070D2);
  static const deepBlue = Color(0xFF004B97);
  static const domeGold = Color(0xFFF5B718);
  static const warmGold = Color(0xFFFFD147);

  static const lightBg = Color(0xFFF3F7FD);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFD6E2F5);

  static const okGreen = Color(0xFF22C55E);
  static const warnAmber = Color(0xFFF59E0B);
  static const errRed = Color(0xFFEF4444);

  static ThemeData darkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: royalBlue,
      brightness: Brightness.dark,
      primary: domeGold,
      secondary: royalBlue,
      surface: midnightSurface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: midnightBg,
      cardTheme: CardThemeData(
        color: midnightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: midnightBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: domeGold,
          foregroundColor: midnightBg,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: midnightBorder),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: midnightBorder),
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
      colorScheme: scheme,
      scaffoldBackgroundColor: lightBg,
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: deepBlue,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: deepBlue,
          side: const BorderSide(color: lightBorder),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: lightBorder),
    );
  }
}
