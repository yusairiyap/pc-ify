import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/app_lock/setup_password_screen.dart';
import 'features/app_lock/setup_pin_screen.dart';
import 'features/browser/background_crop_screen.dart';
import 'features/browser/background_video_trim_screen.dart';
import 'features/browser/browser_screen.dart';
import 'features/browser/image_picker_screen.dart';
import 'features/browser/split_browser_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/split_view/split_view_screen.dart';
import 'features/home/home_screen.dart';
import 'features/image_gallery/image_gallery_screen.dart';
import 'features/settings/backup_restore_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/setup/setup_screen.dart';
import 'features/video_player/video_player_screen.dart';
import 'providers/http_providers.dart';
import 'providers/services_providers.dart';
import 'widgets/main_shell.dart' show MainShell, AnimatedTabContainer;

final routerProvider = Provider<GoRouter>((ref) {
  final routerNotifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/setup',
    refreshListenable: routerNotifier,
    redirect: (context, state) async {
      final expired = ref.read(sessionExpiredProvider);
      if (expired) {
        ref.read(sessionExpiredProvider.notifier).state = false;
        return '/setup';
      }

      final conn = ref.read(connectionServiceProvider);
      final auth = ref.read(authTokenServiceProvider);
      final isAuthenticated = conn.isConfigured && await auth.isTokenValid();

      // Redirect authenticated users away from /setup to /home.
      if (state.matchedLocation == '/setup' && isAuthenticated) return '/home';

      // Show the onboarding wizard on first launch for unauthenticated users.
      if (state.matchedLocation != '/welcome' && !isAuthenticated) {
        final prefs = ref.read(sharedPrefsProvider);
        final onboardingDone =
            prefs.getBool('client_onboarding_completed') ?? false;
        if (!onboardingDone) return '/welcome';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        pageBuilder: (_, state) => _fadeZoomPage(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: '/setup',
        pageBuilder: (_, state) => _slideRightPage(state, const SetupScreen()),
      ),
      StatefulShellRoute(
        pageBuilder: (context, state, shell) => _fadeZoomPage(
          state,
          MainShell(shell: shell),
        ),
        navigatorContainerBuilder: (context, shell, children) =>
            AnimatedTabContainer(
              currentIndex: shell.currentIndex,
              children: children,
            ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/browse',
              builder: (context, state) => BrowserScreen(
                // Key on the timestamp so each bookmark tap forces a fresh widget tree,
                // resetting the notifier history even if the path hasn't changed.
                key: ValueKey(state.uri.queryParameters['t'] ?? ''),
                path: state.uri.queryParameters['path'],
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (_, __) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'backup-restore',
                  builder: (_, __) => const BackupRestoreScreen(),
                ),
                GoRoute(
                  path: 'security/setup-pin',
                  builder: (_, state) => SetupPinScreen(
                    isChange: state.uri.queryParameters['change'] == 'true',
                  ),
                ),
                GoRoute(
                  path: 'security/setup-password',
                  builder: (_, state) => SetupPasswordScreen(
                    isChange: state.uri.queryParameters['change'] == 'true',
                  ),
                ),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/player',
        pageBuilder: (context, state) => _slideUpPage(
          state,
          VideoPlayerScreen(
            filePath: state.uri.queryParameters['path'] ?? '',
            fileName: state.uri.queryParameters['name'] ?? '',
            initialPositionMs: int.tryParse(
                state.uri.queryParameters['pos'] ?? ''),
          ),
        ),
      ),
      GoRoute(
        path: '/gallery',
        pageBuilder: (context, state) => _slideUpPage(
          state,
          ImageGalleryScreen(
            folderPath: state.uri.queryParameters['path'] ?? '',
            startIndex:
                int.tryParse(state.uri.queryParameters['index'] ?? '0') ?? 0,
          ),
        ),
      ),
      GoRoute(
        path: '/image-picker',
        pageBuilder: (context, state) => _slideUpPage(
          state,
          ImagePickerScreen(startPath: state.uri.queryParameters['path'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/background-crop',
        pageBuilder: (context, state) {
          final imageUri = state.extra as String? ?? '';
          final imagePath = state.uri.queryParameters['imagePath'] ?? '';
          return _slideUpPage(
            state,
            BackgroundCropScreen(imageUri: imageUri, imagePath: imagePath),
          );
        },
      ),
      GoRoute(
        path: '/background-video-trim',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return _slideUpPage(
            state,
            BackgroundVideoTrimScreen(
              videoUri: extra['videoUri'] as String? ?? '',
              videoPath: extra['videoPath'] as String? ?? '',
              initialStartMs: extra['startMs'] as int?,
              initialEndMs: extra['endMs'] as int?,
            ),
          );
        },
      ),
      GoRoute(
        path: '/split-view',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final folderPath = extra['folderPath'] as String? ?? '';
          final entries = (extra['entries'] as List<SplitViewEntry>?) ?? [];
          return _slideUpPage(
            state,
            SplitViewScreen(folderPath: folderPath, selectedItems: entries),
          );
        },
      ),
      GoRoute(
        path: '/split-browser',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final path1 = extra['path1'] as String? ?? '';
          final path2 = extra['path2'] as String? ?? '';
          return _slideUpPage(
            state,
            SplitBrowserScreen(path1: path1, path2: path2),
          );
        },
      ),
    ],
  );
});

/// Slide up from the bottom — used for full-screen modal routes (player, gallery, etc.)
CustomTransitionPage<void> _slideUpPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: animation.drive(
          Tween(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: child,
      );
    },
  );
}

/// Slide in from the right — used when moving forward in the setup flow.
CustomTransitionPage<void> _slideRightPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: animation.drive(
          Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

/// Fade + scale forward — used for screen replacements (welcome → home).
CustomTransitionPage<T> _fadeZoomPage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(sessionExpiredProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
