import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/app_lock/setup_password_screen.dart';
import 'features/app_lock/setup_pin_screen.dart';
import 'features/browser/background_crop_screen.dart';
import 'features/browser/background_video_trim_screen.dart';
import 'features/browser/browser_screen.dart';
import 'features/browser/image_picker_screen.dart';
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

      if (state.matchedLocation == '/setup') {
        final conn = ref.read(connectionServiceProvider);
        final auth = ref.read(authTokenServiceProvider);
        if (conn.isConfigured && await auth.isTokenValid()) {
          return '/home';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),
      StatefulShellRoute(
        builder: (context, state, shell) => MainShell(shell: shell),
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
    ],
  );
});

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

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(sessionExpiredProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
