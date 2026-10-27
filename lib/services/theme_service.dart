import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service managing app-wide ThemeMode (Light vs Dark)
/// with instant reactivity and persistent storage via SharedPreferences.
class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService._();
  ThemeService._();

  static const String _prefKey = 'app_theme_mode';
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark mode as requested

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        // Default to dark theme matching user request
        _themeMode = ThemeMode.dark;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  Future<void> setDarkMode(bool dark) async {
    _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }
}
