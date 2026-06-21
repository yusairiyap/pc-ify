import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/app_lock/app_lock_providers.dart';
import 'features/app_lock/lock_overlay.dart';
import 'providers/services_providers.dart';
import 'providers/theme_providers.dart';
import 'router.dart';
import 'services/theme_service.dart';
import 'widgets/transfer_overlay.dart';

class PcIfyApp extends ConsumerStatefulWidget {
  const PcIfyApp({super.key});

  @override
  ConsumerState<PcIfyApp> createState() => _PcIfyAppState();
}

class _PcIfyAppState extends ConsumerState<PcIfyApp>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _armOnColdStart());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _armOnColdStart() async {
    final lockService = ref.read(appLockServiceProvider);
    if (!lockService.isEnabled) return;
    // If there is no valid session the router will redirect to /setup —
    // unlock so the lock screen doesn't stack on top of it.
    final auth = ref.read(authTokenServiceProvider);
    if (!await auth.isTokenValid()) {
      ref.read(lockNotifierProvider.notifier).unlock();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lockService = ref.read(appLockServiceProvider);
    if (!lockService.isEnabled) return;

    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final bg = _backgroundedAt;
      if (bg == null) return;
      final elapsed = DateTime.now().difference(bg).inSeconds;
      if (elapsed >= lockService.gracePeriodSeconds) {
        ref.read(lockNotifierProvider.notifier).lock();
      }
      _backgroundedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeNotifierProvider);
    final router = ref.watch(routerProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Follow the OS / wallpaper accent (Material You) when in system mode
        // and the platform actually provides a dynamic scheme. We seed
        // ColorScheme.fromSeed with the wallpaper's primary colour (rather than
        // using the raw dynamic scheme) so the surface/container tones are
        // generated with the same tonal principles as the preset accents —
        // otherwise cards blend into the background.
        final useSystem = themeState.accentMode == AccentMode.system &&
            lightDynamic != null &&
            darkDynamic != null;
        final seed =
            useSystem ? lightDynamic.primary : themeState.accentColor;

        final scheme = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        );
        final schemeDark = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        );

        return MaterialApp.router(
          title: 'pc-ify',
          themeMode: themeState.mode,
          theme: buildAppTheme(scheme),
          darkTheme: buildAppTheme(schemeDark),
          routerConfig: router,
          builder: (context, child) {
            final lockState = ref.watch(lockNotifierProvider);
            Widget content = TransferOverlay(child: child!);
            if (!lockState.isLocked) return content;
            // Wrap in a Navigator so TextField inside LockOverlay can find an
            // Overlay ancestor (MaterialApp.router's builder sits above the
            // Router's own Navigator/Overlay). Navigator also handles lifecycle
            // correctly when removed from the tree.
            return Stack(
              children: [
                content,
                Positioned.fill(
                  child: Theme(
                    data: Theme.of(context),
                    child: Navigator(
                      onGenerateRoute: (_) => PageRouteBuilder<void>(
                        pageBuilder: (_, __, ___) =>
                            LockOverlay(lockType: lockState.lockType),
                        opaque: true,
                        barrierDismissible: false,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
