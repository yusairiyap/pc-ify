import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services_providers.dart';

class ThemeState {
  const ThemeState({required this.mode, required this.accentColor});
  final ThemeMode mode;
  final Color accentColor;

  ThemeState copyWith({ThemeMode? mode, Color? accentColor}) => ThemeState(
        mode: mode ?? this.mode,
        accentColor: accentColor ?? this.accentColor,
      );
}

class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    final svc = ref.watch(themeServiceProvider);
    return ThemeState(
      mode: svc.getThemeMode(),
      accentColor: svc.getAccentColor(),
    );
  }

  Future<void> apply(ThemeMode mode, Color accentColor) async {
    final svc = ref.read(themeServiceProvider);
    await Future.wait([
      svc.saveThemeMode(mode),
      svc.saveAccentColor(accentColor),
    ]);
    state = state.copyWith(mode: mode, accentColor: accentColor);
  }
}

final themeNotifierProvider = NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
