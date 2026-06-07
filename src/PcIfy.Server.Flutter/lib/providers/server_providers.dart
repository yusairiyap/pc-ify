import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/http_server_service.dart';
import '../services/platform/foreground_service.dart';
import 'settings_providers.dart';
import 'log_providers.dart';

final httpServerServiceProvider = Provider<HttpServerService>((ref) {
  final settings = ref.watch(settingsProvider);
  final logSvc = ref.watch(connectionLogServiceProvider);
  final settingsSvc = ref.read(settingsServiceProvider);
  final svc = HttpServerService(settings, logSvc, settingsSvc);
  ref.onDispose(() async {
    await svc.dispose();
    // If settings change while the server is running, Riverpod disposes this
    // provider and recreates it. Ensure the foreground service notification
    // is also removed so it doesn't stay visible after the server stops.
    if (Platform.isAndroid) {
      await ForegroundServiceHelper.instance.stop();
    }
  });
  return svc;
});

final serverStateProvider = StreamProvider<ServerState>((ref) {
  final svc = ref.watch(httpServerServiceProvider);
  return svc.stateStream;
});

/// Returns the ForegroundService registered by main.dart on Android,
/// or a no-op on all other platforms.
final foregroundServiceProvider = Provider<ForegroundService>((ref) {
  return ForegroundServiceHelper.instance;
});
