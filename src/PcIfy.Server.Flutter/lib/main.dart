import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'providers/settings_providers.dart';
import 'providers/server_providers.dart';
import 'providers/theme_providers.dart';
import 'services/ffmpeg_setup_service.dart';
import 'services/platform/mobile_video_thumbnail.dart'
    as mobile_thumb;
import 'services/settings_service.dart';
import 'services/thumbnail_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load settings before building the widget tree.
  final settingsSvc = SettingsService();
  await settingsSvc.load();

  final prefs = await SharedPreferences.getInstance();

  // Desktop-only: window manager + tray.
  if (Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    await windowManager.setTitle('pc-ify server');
    await windowManager.setMinimumSize(const Size(640, 480));

    // Probe for an already-downloaded FFmpeg binary.
    await FFmpegSetupService.configure();
  }

  // Android: register video_thumbnail helper.
  if (Platform.isAndroid) {
    _registerMobileVideoThumbnail();
  }

  runApp(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWithValue(settingsSvc),
        settingsProvider.overrideWith(
            (ref) => SettingsNotifier(settingsSvc)
              ..state = settingsSvc.settings),
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: _AppWithWindowManager(
        autoStart: settingsSvc.settings.autoStart &&
            settingsSvc.settings.sourceDirectories.isNotEmpty &&
            settingsSvc.settings.users.isNotEmpty,
      ),
    ),
  );
}

void _registerMobileVideoThumbnail() {
  PlatformThumbnailHelper.register(mobile_thumb.getMobileVideoThumbnail);
}

/// Thin wrapper that wires window_manager minimize-to-tray on desktop.
class _AppWithWindowManager extends ConsumerStatefulWidget {
  final bool autoStart;
  const _AppWithWindowManager({required this.autoStart});

  @override
  ConsumerState<_AppWithWindowManager> createState() =>
      _AppWithWindowManagerState();
}

class _AppWithWindowManagerState extends ConsumerState<_AppWithWindowManager> {
  // Separate listener object so we only need to override onWindowClose,
  // inheriting default no-op stubs for all other WindowListener methods.
  late final _CloseListener _windowListener;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isMacOS) {
      _windowListener = _CloseListener();
      windowManager.addListener(_windowListener);
    }
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoStart());
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isMacOS) {
      windowManager.removeListener(_windowListener);
    }
    super.dispose();
  }

  Future<void> _autoStart() async {
    final settings = ref.read(settingsProvider);
    final svc = ref.read(httpServerServiceProvider);
    await svc.start(settings.port);
  }

  @override
  Widget build(BuildContext context) => const PcIfyServerApp();
}

/// Extends (not implements) WindowListener so only onWindowClose needs
/// an override — all other callbacks inherit empty default bodies.
class _CloseListener extends WindowListener {
  @override
  Future<void> onWindowClose() async {
    await windowManager.hide();
  }
}

