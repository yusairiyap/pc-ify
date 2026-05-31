import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/main_screen/main_screen.dart';
import 'providers/theme_providers.dart';

class PcIfyServerApp extends ConsumerWidget {
  const PcIfyServerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeNotifierProvider);
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
      home: const MainScreen(),
    );
  }
}
