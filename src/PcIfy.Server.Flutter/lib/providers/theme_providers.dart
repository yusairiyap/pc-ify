import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState {
  final ThemeMode mode;
  final Color accentColor;

  const ThemeState({required this.mode, required this.accentColor});

  static const initial = ThemeState(
    mode: ThemeMode.system,
    accentColor: Color(0xFF7C4DFF),
  );
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  final SharedPreferences _prefs;
  static const _modeKey = 'themeMode';
  static const _colorKey = 'accentColor';

  ThemeNotifier(this._prefs)
      : super(ThemeState(
          mode: _loadMode(_prefs),
          accentColor: _loadColor(_prefs),
        ));

  Future<void> apply(ThemeMode mode, Color color) async {
    await _prefs.setString(_modeKey, mode.name);
    await _prefs.setInt(_colorKey, color.value);
    state = ThemeState(mode: mode, accentColor: color);
  }

  static ThemeMode _loadMode(SharedPreferences p) {
    final name = p.getString(_modeKey) ?? 'system';
    return ThemeMode.values.firstWhere((m) => m.name == name,
        orElse: () => ThemeMode.system);
  }

  static Color _loadColor(SharedPreferences p) {
    final v = p.getInt(_colorKey);
    return v != null ? Color(v) : const Color(0xFF7C4DFF);
  }
}

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

final themeNotifierProvider =
    StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier(ref.watch(sharedPrefsProvider));
});
