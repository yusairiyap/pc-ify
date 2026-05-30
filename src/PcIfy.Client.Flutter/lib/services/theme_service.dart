import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  ThemeService(this._prefs);

  final SharedPreferences _prefs;
  static const _modeKey = 'theme_mode';
  static const _accentKey = 'accent_color';

  static const List<Color> presetColors = [
    Color(0xFF512BD4), // Purple (default)
    Color(0xFF1565C0), // Blue
    Color(0xFF00897B), // Teal
    Color(0xFF2E7D32), // Green
    Color(0xFFE65100), // Orange
    Color(0xFFC62828), // Red
    Color(0xFFAD1457), // Pink
    Color(0xFF37474F), // Blue-Grey
    Color(0xFF212121), // Dark-Grey
  ];

  ThemeMode getThemeMode() {
    final saved = _prefs.getString(_modeKey) ?? 'system';
    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Color getAccentColor() {
    final value = _prefs.getInt(_accentKey);
    if (value == null) return presetColors.first;
    return Color(value);
  }

  Future<void> saveThemeMode(ThemeMode mode) {
    final s = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    return _prefs.setString(_modeKey, s);
  }

  Future<void> saveAccentColor(Color color) =>
      _prefs.setInt(_accentKey, color.toARGB32());
}
