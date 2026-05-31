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

class _AppWithWindowManagerState extends ConsumerState<_AppWithWindowManager>
    implements WindowListener {
  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isMacOS) {
      windowManager.addListener(this);
    }
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoStart());
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _autoStart() async {
    final settings = ref.read(settingsProvider);
    final svc = ref.read(httpServerServiceProvider);
    await svc.start(settings.port);
  }

  // Minimize to tray instead of closing.
  @override
  Future<void> onWindowClose() async {
    await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) => const PcIfyServerApp();

  // Unused WindowListener callbacks.
  @override void onWindowBlur() {}
  @override void onWindowDocked() {}
  @override void onWindowEnterFullScreen() {}
  @override void onWindowEvent(String eventName) {}
  @override void onWindowFocus() {}
  @override void onWindowLeaveFullScreen() {}
  @override void onWindowMaximize() {}
  @override void onWindowMinimize() {}
  @override void onWindowMinimizeStart() {}
  @override void onWindowMinimizeEnd() {}
  @override void onWindowMaximizeStart() {}
  @override void onWindowMaximizeEnd() {}
  @override void onWindowMove() {}
  @override void onWindowMoveStart() {}
  @override void onWindowMoveEnd() {}
  @override void onWindowResize() {}
  @override void onWindowResizeStart() {}
  @override void onWindowResizeEnd() {}
  @override void onWindowRestore() {}
  @override void onWindowScrollTouchBegin() {}
  @override void onWindowScrollTouchEnd() {}
  @override void onWindowScrollTouchUpdate() {}
  @override void onWindowUndocked() {}
  @override void onWindowUnmaximize() {}
}

