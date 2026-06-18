import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/theme_service.dart';
import 'services_providers.dart';

class ThemeState {
  const ThemeState({
    required this.mode,
    required this.accentColor,
    required this.accentMode,
  });

  final ThemeMode mode;

  /// Preset seed colour — used when [accentMode] is [AccentMode.preset], or as
  /// the fallback when the system has no dynamic scheme.
  final Color accentColor;
  final AccentMode accentMode;

  ThemeState copyWith({
    ThemeMode? mode,
    Color? accentColor,
    AccentMode? accentMode,
  }) =>
      ThemeState(
        mode: mode ?? this.mode,
        accentColor: accentColor ?? this.accentColor,
        accentMode: accentMode ?? this.accentMode,
      );
}

class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    final svc = ref.watch(themeServiceProvider);
    return ThemeState(
      mode: svc.getThemeMode(),
      accentColor: svc.getAccentColor(),
      accentMode: svc.getAccentMode(),
    );
  }

  Future<void> apply(
    ThemeMode mode, {
    Color? accentColor,
    AccentMode? accentMode,
  }) async {
    final svc = ref.read(themeServiceProvider);
    final newColor = accentColor ?? state.accentColor;
    final newAccentMode = accentMode ?? state.accentMode;
    await Future.wait([
      svc.saveThemeMode(mode),
      svc.saveAccentMode(newAccentMode),
      if (accentColor != null) svc.saveAccentColor(newColor),
    ]);
    state = state.copyWith(
      mode: mode,
      accentColor: newColor,
      accentMode: newAccentMode,
    );
  }
}

final themeNotifierProvider =
    NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
