import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';

/// Mengelola pilihan tema dan menyimpannya di perangkat.
class ThemeService extends ChangeNotifier {
  ThemeService._();

  static final ThemeService instance = ThemeService._();
  static const String _preferenceKey = 'hydro_dark_mode';

  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_preferenceKey) ?? false;
    } catch (_) {
      _isDarkMode = false;
    }
    AppColors.isDarkMode = _isDarkMode;
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;

    _isDarkMode = value;
    AppColors.isDarkMode = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_preferenceKey, value);
    } catch (_) {
      // Tema tetap dapat dipakai selama aplikasi berjalan jika penyimpanan gagal.
    }
  }
}
