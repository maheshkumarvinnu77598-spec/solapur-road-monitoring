import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';

const Color _primary = Color(0xFF77B6EA);
const Color _background = Color(0xFFE8EEF2);
const Color _card = Color(0xFFC7D3DD);
const Color _accent = Color(0xFFD6C9C9);
const Color _text = Color(0xFF37393A);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyDh2QTNWyQ88piHmmVnLpRV5tPoWiEHJH4',
      appId: '1:94080701473:web:56a39eb44cc6568f177f60',
      messagingSenderId: '94080701473',
      projectId: 'solapur-road-monitoring',
      storageBucket: 'solapur-road-monitoring.firebasestorage.app',
    ),
  );
  runApp(const AdminDashboardApp());
}

class AdminDashboardApp extends StatelessWidget {
  const AdminDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = const ColorScheme.light().copyWith(
      primary: _primary,
      secondary: _accent,
      surface: _card,
      onSurface: _text,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Solapur Admin Dashboard',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: _background,
        cardTheme: CardThemeData(
          color: _card,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: EdgeInsets.zero,
        ),
        textTheme: Theme.of(
          context,
        ).textTheme.apply(bodyColor: _text, displayColor: _text),
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: _text,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white70,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary),
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
