abstract class ForegroundService {
  /// Creates the notification channel up-front so it exists before the service
  /// is ever started. Safe to call multiple times. No-op off Android.
  Future<void> init() async {}

  Future<void> start(int port);
  Future<void> stop();
  bool get isRunning;

  /// Whether the OS notification permission (Android 13+) is granted. When this
  /// is false the foreground-service notification cannot be shown even though
  /// the service itself keeps running.
  Future<bool> isNotificationPermissionGranted() async => true;

  /// Requests the Android 13+ POST_NOTIFICATIONS permission. Returns whether it
  /// ended up granted.
  Future<bool> requestNotificationPermission() async => true;

  /// Whether the app is exempt from battery optimization (Doze). On aggressive
  /// OEMs (Samsung/Xiaomi/OPPO/Vivo) this is the single biggest factor in the
  /// process surviving in the background.
  Future<bool> isBatteryOptimizationIgnored() async => true;

  /// Shows the system dialog asking the user to exempt the app from battery
  /// optimization.
  Future<void> requestBatteryOptimizationExemption() async {}
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
