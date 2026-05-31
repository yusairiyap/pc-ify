abstract class TrayService {
  Future<void> init();
  void setRunning(bool running, int? port);
  void setTheme(bool isDark);
  void showNotification(String title, String body);
  void dispose();
}
