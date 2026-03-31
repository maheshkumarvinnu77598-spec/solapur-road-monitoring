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
<<<<<<< HEAD
=======
          secondary: AppPalette.accent,
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
          surface: AppPalette.card,
          onSurface: AppPalette.text,
          onPrimary: Colors.white,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.background,
<<<<<<< HEAD
      cardTheme: CardThemeData(
        color: AppPalette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
=======
      dividerColor: AppPalette.card.withValues(alpha: 0.7),
      cardTheme: CardThemeData(
        color: AppPalette.card,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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
<<<<<<< HEAD
        bodyMedium: TextStyle(color: AppPalette.text),
=======
        titleLarge: TextStyle(
          color: AppPalette.text,
          fontWeight: FontWeight.w700,
        ),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
        titleMedium: TextStyle(
          color: AppPalette.text,
          fontWeight: FontWeight.w600,
        ),
<<<<<<< HEAD
=======
        bodyLarge: TextStyle(color: AppPalette.text),
        bodyMedium: TextStyle(color: AppPalette.text),
        labelLarge: TextStyle(color: Colors.white),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      ),
    );
  }

  static ThemeData get dark {
<<<<<<< HEAD
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
=======
    const Color scaffold = Color(0xFF121212);
    const Color card = Color(0xFF1E1E1E);
    const Color field = Color(0xFF262626);
    final ColorScheme scheme = const ColorScheme.dark().copyWith(
      primary: AppPalette.primary,
      secondary: AppPalette.accent,
      surface: card,
      onSurface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      dividerColor: const Color(0xFF2C2C2C),
      cardTheme: CardThemeData(
        color: card,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
<<<<<<< HEAD
        fillColor: const Color(0xFF3A4348),
=======
        fillColor: field,
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
<<<<<<< HEAD
=======
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.primary, width: 1.4),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white60),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white70),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white70,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: field,
        labelStyle: const TextStyle(color: Colors.white),
        selectedColor: AppPalette.primary,
        secondarySelectedColor: AppPalette.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        foregroundColor: Colors.white,
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      ),
    );
  }
}
