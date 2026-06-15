import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _keyDarkMode = 'dark_mode';

  ThemeMode _currentThemeMode;
  ThemeMode get currentThemeMode => _currentThemeMode;

  bool get isDarkMode => _currentThemeMode == ThemeMode.dark;

  ThemeProvider({bool isDark = false})
      : _currentThemeMode = isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> toggleTheme() async {
    _currentThemeMode =
        _currentThemeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, _currentThemeMode == ThemeMode.dark);
  }

  Future<void> changeTheme(ThemeMode mode) async {
    _currentThemeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, mode == ThemeMode.dark);
  }
}
