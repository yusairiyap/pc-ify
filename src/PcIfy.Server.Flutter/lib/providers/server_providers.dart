import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/http_server_service.dart';
import '../services/platform/foreground_service.dart';
import 'settings_providers.dart';
import 'log_providers.dart';

final httpServerServiceProvider = Provider<HttpServerService>((ref) {
  final settings = ref.watch(settingsProvider);
  final logSvc = ref.watch(connectionLogServiceProvider);
  final svc = HttpServerService(settings, logSvc);
  ref.onDispose(svc.dispose);
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
