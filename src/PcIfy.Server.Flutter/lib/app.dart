import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/main_screen/main_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'providers/settings_providers.dart';
import 'providers/theme_providers.dart';

class PcIfyServerApp extends ConsumerWidget {
  const PcIfyServerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifierProvider);
    // The onboarding wizard only makes sense on Android (battery / notification
    // / autostart). Elsewhere we always go straight to the main screen.
    final needsOnboarding = Platform.isAndroid &&
        !ref.watch(settingsProvider.select((s) => s.onboardingCompleted));
    final scheme = ColorScheme.fromSeed(seedColor: theme.accentColor);
    final schemeDark = ColorScheme.fromSeed(
        seedColor: theme.accentColor, brightness: Brightness.dark);

    return MaterialApp(
      title: 'pc-ify server',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          brightness: Brightness.light),
      darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: schemeDark,
          brightness: Brightness.dark),
      themeMode: theme.mode,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(needsOnboarding),
          child: needsOnboarding ? const WelcomeScreen() : const MainScreen(),
        ),
      ),
    );
  }
}
