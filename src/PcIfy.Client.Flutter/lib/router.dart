import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/browser/browser_screen.dart';
import 'features/browser/image_picker_screen.dart';
import 'features/home/home_screen.dart';
import 'features/image_gallery/image_gallery_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/setup/setup_screen.dart';
import 'features/video_player/video_player_screen.dart';
import 'providers/http_providers.dart';
import 'providers/services_providers.dart';
import 'widgets/main_shell.dart';

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
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
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
                path: state.uri.queryParameters['path'],
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (_, __) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/browser',
        builder: (context, state) => BrowserScreen(
          path: state.uri.queryParameters['path'],
        ),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) => VideoPlayerScreen(
          filePath: state.uri.queryParameters['path'] ?? '',
          fileName: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: '/gallery',
        builder: (context, state) => ImageGalleryScreen(
          folderPath: state.uri.queryParameters['path'] ?? '',
          startIndex:
              int.tryParse(state.uri.queryParameters['index'] ?? '0') ?? 0,
        ),
      ),
      GoRoute(
        path: '/image-picker',
        builder: (context, state) => ImagePickerScreen(
          startPath: state.uri.queryParameters['path'] ?? '',
        ),
      ),
    ],
  );
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(sessionExpiredProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
