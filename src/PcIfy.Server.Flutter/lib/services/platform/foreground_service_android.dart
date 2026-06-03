import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'foreground_service.dart';

// Entry point for the foreground task — runs in a separate Flutter engine.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_ServerTaskHandler());
}

class _ServerTaskHandler extends TaskHandler {
  // v8 API: onStart now receives a TaskStarter alongside the timestamp.
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // The HTTP server lifecycle is managed by the main isolate.
    // The foreground service just keeps the process alive.
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onReceiveData(Object data) {}

  // NOTE on Android 15 (API 35): a `dataSync` foreground service is limited to
  // ~6 hours of background runtime per 24h, after which the platform calls
  // Service.onTimeout() and stops it. flutter_foreground_task v8 does not surface
  // that native callback to Dart, so it cannot be intercepted here. The timer
  // resets whenever the app returns to the foreground. Battery-optimization
  // exemption + the persistent notification + autoRunOnBoot keep the common
  // "dies on minimize" case working; the 24h cap is a platform constraint.
}

class ForegroundServiceImpl extends ForegroundService {
  bool _running = false;

  @override
  bool get isRunning => _running;

  /// Builds the notification channel + task options. Calling this early (from
  /// main.dart) guarantees the channel exists before the service is ever
  /// started.
  @override
  Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        // Use a versioned channel ID so that Android creates a fresh channel
        // with DEFAULT importance on devices that already cached the old
        // 'pcify_server' channel as LOW (Android does not let apps downgrade
        // an existing channel's importance once set by the user/system).
        channelId: 'pcify_server_v2',
        channelName: 'pc-ify Server',
        channelDescription: 'Keeps the pc-ify server running in background',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
      ),
      // v8: IOSNotificationOptions no longer accepts showNotification.
      iosNotificationOptions: const IOSNotificationOptions(),
      // v8: ForegroundTaskOptions constructor is not const.
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        // Restart the service after a reboot (the BootReceiver is declared in
        // AndroidManifest.xml) so the server comes back without manual launch.
        autoRunOnBoot: true,
        allowWifiLock: true,
      ),
    );
  }

  @override
  Future<bool> isNotificationPermissionGranted() async {
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    return permission == NotificationPermission.granted;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    if (await isNotificationPermissionGranted()) return true;
    final result = await FlutterForegroundTask.requestNotificationPermission();
    return result == NotificationPermission.granted;
  }

  @override
  Future<bool> isBatteryOptimizationIgnored() async {
    return FlutterForegroundTask.isIgnoringBatteryOptimizations;
  }

  @override
  Future<void> requestBatteryOptimizationExemption() async {
    // Direct system dialog (needs REQUEST_IGNORE_BATTERY_OPTIMIZATIONS in the
    // manifest). For Play Store submission this permission requires Console
    // justification; openIgnoreBatteryOptimizationSettings() is the always-allowed
    // fallback if that ever becomes a problem.
    if (!await isBatteryOptimizationIgnored()) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  @override
  Future<void> start(int port) async {
    // Make sure the channel/options exist even if init() wasn't called yet.
    await init();

    // Android 13+ requires POST_NOTIFICATIONS to be granted at runtime before
    // the foreground-service notification can appear in the notification panel.
    // We still start the service if it's denied (the server must run), but the
    // UI surfaces the missing permission so the user can fix it.
    await requestNotificationPermission();

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'pc-ify server',
      notificationText: 'Running on port $port',
      callback: startCallback,
    );
    _running = true;
  }

  @override
  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    _running = false;
  }
}
