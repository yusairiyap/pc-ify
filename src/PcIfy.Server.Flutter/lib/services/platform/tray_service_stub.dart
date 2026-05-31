import 'tray_service.dart';

class TrayServiceImpl extends TrayService {
  @override
  Future<void> init() async {}

  @override
  void setRunning(bool running, int? port) {}

  @override
  void setTheme(bool isDark) {}

  @override
  void showNotification(String title, String body) {}

  @override
  void dispose() {}
}
