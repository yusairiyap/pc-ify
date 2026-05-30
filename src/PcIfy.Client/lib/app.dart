import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/theme_providers.dart';
import 'router.dart';

class PcIfyApp extends ConsumerWidget {
  const PcIfyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeNotifierProvider);
    final router = ref.watch(routerProvider);

    final scheme = ColorScheme.fromSeed(
      seedColor: themeState.accentColor,
      brightness: Brightness.light,
    );
    final schemeDark = ColorScheme.fromSeed(
      seedColor: themeState.accentColor,
      brightness: Brightness.dark,
    );

    return MaterialApp.router(
      title: 'pc-ify',
      themeMode: themeState.mode,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: schemeDark,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
