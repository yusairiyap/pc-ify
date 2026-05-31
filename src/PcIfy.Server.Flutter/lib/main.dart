import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'providers/settings_providers.dart';
import 'providers/server_providers.dart';
import 'providers/theme_providers.dart';
import 'services/ffmpeg_setup_service.dart';
import 'services/platform/foreground_service_android.dart'
    as fg_android;
import 'services/platform/foreground_service.dart';
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

  // Android: flutter_foreground_task v8 requires initCommunicationPort() to
  // be called in main() before runApp(). Without it the callback isolate
  // cannot register its handler and startService() fails silently — no
  // notification channel is ever created.
  if (Platform.isAndroid) {
    FlutterForegroundTask.initCommunicationPort();
    _registerAndroidServices();
  }

  runApp(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWithValue(settingsSvc),
        settingsProvider.overrideWith((ref) => SettingsNotifier(settingsSvc)),
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

void _registerAndroidServices() {
  ForegroundServiceHelper.register(fg_android.ForegroundServiceImpl());
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
    await ref.read(httpServerServiceProvider).start(settings.port);
    if (Platform.isAndroid) {
      await ref.read(foregroundServiceProvider).start(settings.port);
    }
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

