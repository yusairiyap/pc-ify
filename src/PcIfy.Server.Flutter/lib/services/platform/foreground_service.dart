abstract class ForegroundService {
  Future<void> start(int port);
  Future<void> stop();
  bool get isRunning;
}

class _NoOpForegroundService extends ForegroundService {
  @override
  Future<void> start(int port) async {}
  @override
  Future<void> stop() async {}
  @override
  bool get isRunning => false;
}

/// Static registration point, analogous to PlatformThumbnailHelper.
/// On Android, main.dart calls register(ForegroundServiceImpl()) before runApp.
/// On all other platforms the no-op implementation is used.
class ForegroundServiceHelper {
  static ForegroundService _instance = _NoOpForegroundService();

  static void register(ForegroundService impl) {
    _instance = impl;
  }

  static ForegroundService get instance => _instance;
}
