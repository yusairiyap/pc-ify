import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'tray_service.dart';

class TrayServiceImpl extends TrayService implements TrayListener {
  bool _isRunning = false;
  int? _port;

  VoidCallback? onShowWindow;
  VoidCallback? onStartStop;
  VoidCallback? onToggleTheme;
  VoidCallback? onExit;

  @override
  Future<void> init() async {
    trayManager.addListener(this);
    await _updateTray();
  }

  @override
  void setRunning(bool running, int? port) {
    _isRunning = running;
    _port = port;
    _updateTray();
  }

  @override
  void setTheme(bool isDark) {
    _updateTray();
  }

  @override
  void showNotification(String title, String body) {
    // tray_manager supports balloons on Windows via trayManager.popUpContextMenu
    // and tooltip updates; a full balloon requires local_notifier or similar.
    // For now, update the tooltip to surface the message.
    trayManager.setToolTip('$title — $body');
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    trayManager.destroy();
  }

  Future<void> _updateTray() async {
    final tooltip = _isRunning
        ? 'pc-ify — Running on port $_port'
        : 'pc-ify — Stopped';
    await trayManager.setToolTip(tooltip);

    // Use a simple PNG/ICO asset; real app should provide proper icon files.
    await trayManager.setIcon('assets/icons/tray_icon.png');

    final menu = Menu(items: [
      MenuItem(key: 'show', label: 'Show pc-ify'),
      MenuItem.separator(),
      MenuItem(
          key: 'toggle_server',
          label: _isRunning ? 'Stop Server' : 'Start Server'),
      MenuItem(key: 'toggle_theme', label: 'Toggle Dark / Light'),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: 'Exit'),
    ]);
    await trayManager.setContextMenu(menu);
  }

  // ── TrayListener ──────────────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        windowManager.focus();
        break;
      case 'toggle_server':
        onStartStop?.call();
        break;
      case 'toggle_theme':
        onToggleTheme?.call();
        break;
      case 'exit':
        onExit?.call();
        break;
    }
  }
}

// Re-export so callers don't need to import window_manager directly.
typedef VoidCallback = void Function();
