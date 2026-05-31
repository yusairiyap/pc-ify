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
}

class ForegroundServiceImpl extends ForegroundService {
  bool _running = false;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(int port) async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'pcify_server',
        channelName: 'pc-ify Server',
        channelDescription: 'Keeps the pc-ify server running in background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        // iconData / NotificationIconData removed in flutter_foreground_task v8;
        // the app icon is used automatically.
      ),
      // v8: IOSNotificationOptions no longer accepts showNotification.
      iosNotificationOptions: const IOSNotificationOptions(),
      // v8: ForegroundTaskOptions constructor is not const.
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWifiLock: true,
      ),
    );

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
