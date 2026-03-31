import 'package:flutter/material.dart';

class AppPalette {
  static const Color primary = Color(0xFF77B6EA);
  static const Color background = Color(0xFFE8EEF2);
  static const Color card = Color(0xFFC7D3DD);
  static const Color accent = Color(0xFFD6C9C9);
  static const Color text = Color(0xFF37393A);

  static const Color critical = Color(0xFFD32F2F);
  static const Color high = Color(0xFFF57C00);
  static const Color medium = Color(0xFF1976D2);
  static const Color low = Color(0xFF388E3C);
}

class AppTheme {
  static ThemeData get light {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppPalette.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppPalette.primary,
          surface: AppPalette.card,
          onSurface: AppPalette.text,
          onPrimary: Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.background,
      cardTheme: CardThemeData(
        color: AppPalette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.primary, width: 1.4),
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppPalette.text),
        titleMedium: TextStyle(
          color: AppPalette.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static ThemeData get dark {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppPalette.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppPalette.primary,
          surface: const Color(0xFF2A3136),
          onSurface: Colors.white,
          onPrimary: Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF1C2328),
      cardTheme: CardThemeData(
        color: const Color(0xFF2A3136),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF3A4348),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
