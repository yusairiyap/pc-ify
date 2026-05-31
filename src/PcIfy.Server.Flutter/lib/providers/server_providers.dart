import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/http_server_service.dart';
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

/// Platform-aware foreground service provider.
/// On Android it uses flutter_foreground_task; on other platforms it's a no-op.
final foregroundServiceProvider = Provider<_ForegroundServiceBridge>((ref) {
  return _ForegroundServiceBridge();
});

class _ForegroundServiceBridge {
  Future<void> start(int port) async {
    if (!Platform.isAndroid) return;
    // Imported conditionally at app startup via main.dart.
    await _androidImpl?.start(port);
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _androidImpl?.stop();
  }

  dynamic _androidImpl;

  void setImpl(dynamic impl) => _androidImpl = impl;
}
