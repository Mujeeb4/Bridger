import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand Colors (dark green palette) ──────────────────────────────────
  static const Color primaryGreen = Color(0xFF4ADE80);
  static const Color primaryDarkGreen = Color(0xFF166534);
  static const Color backgroundDark = Color(0xFF0A0F0A);
  static const Color cardDark = Color(0xFF0F1A0F);
  static const Color borderDark = Color(0xFF1A2A1A);
  static const Color surfaceDark = Color(0xFF1A2A1A);

  // Legacy aliases (keep for any old references)
  static const Color primaryColor = primaryGreen;
  static const Color primaryDarkColor = primaryDarkGreen;
  static const Color accentColor = primaryGreen;
  static const Color backgroundColor = backgroundDark;
  static const Color surfaceColor = cardDark;
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = primaryGreen;
  static const Color warningColor = Color(0xFFFFA726);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textHint = Color(0xFF666666);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Connection Status Colors
  static const Color connectedColor = primaryGreen;
  static const Color connectingColor = Color(0xFFFFA726);
  static const Color disconnectedColor = Color(0xFFD32F2F);

  // ── The app is always dark, so both themes are the same dark green ───
  static ThemeData lightTheme = _buildDarkGreenTheme();
  static ThemeData darkTheme = _buildDarkGreenTheme();

  static ThemeData _buildDarkGreenTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        onPrimary: Color(0xFF003300),
        primaryContainer: primaryDarkGreen,
        onPrimaryContainer: primaryGreen,
        secondary: primaryGreen,
        onSecondary: Color(0xFF003300),
        secondaryContainer: primaryDarkGreen,
        onSecondaryContainer: primaryGreen,
        error: Color(0xFFD32F2F),
        surface: cardDark,
        onSurface: Color(0xFFFFFFFF),
        onSurfaceVariant: Color(0xFFAAAAAA),
        outline: borderDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardDark,
        indicatorColor: primaryDarkGreen,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryGreen);
          }
          return const IconThemeData(color: Colors.white54);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: primaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDarkGreen,
          foregroundColor: primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryDarkGreen,
          foregroundColor: primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryDarkGreen,
        foregroundColor: primaryGreen,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryGreen;
          return Colors.white54;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryDarkGreen;
          return const Color(0xFF2A2A2A);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A2A1A),
        hintStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD32F2F)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryDarkGreen,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: Colors.white70,
          fontSize: 15,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryGreen,
      ),
    );
  }

  // Text Styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textHint,
  );
}
