import 'package:flutter/material.dart';

class ThemeModeService {
  ThemeModeService._();

  static final ThemeModeService instance = ThemeModeService._();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  void setMode(ThemeMode mode) {
    themeMode.value = mode;
  }
}
