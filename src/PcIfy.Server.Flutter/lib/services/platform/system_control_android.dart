import 'package:flutter/services.dart';
import '../../core/models/launcher_app.dart';
import 'system_control_service.dart';

class SystemControlAndroidImpl implements SystemControlService {
  static const _channel = MethodChannel('com.pcify.pcify_server/system_control');

  @override
  Future<ControlStatus> getStatus() async {
    try {
      final map = await _channel.invokeMethod<Map>('getStatus');
      if (map == null) return ControlStatus.unavailable();
      final b = map['battery'] as Map? ?? {};
      final v = map['volume'] as Map? ?? {};
      final c = map['cpu'] as Map? ?? {};
      final r = map['ram'] as Map? ?? {};
      final s = map['screen'] as Map? ?? {};
      final d = map['disk'] as Map? ?? {};
      return ControlStatus(
        battery: BatteryStatus(
          level: (b['level'] as int?) ?? 0,
          charging: (b['charging'] as bool?) ?? false,
          available: (b['available'] as bool?) ?? false,
          temperatureCelsius: (b['temperatureCelsius'] as int?) ?? 0,
          temperatureAvailable: (b['temperatureAvailable'] as bool?) ?? false,
        ),
        volume: VolumeStatus(
          level: (v['level'] as int?) ?? 50,
          muted: (v['muted'] as bool?) ?? false,
          available: (v['available'] as bool?) ?? false,
        ),
        cpu: CpuStatus(
          usage: ((c['usage'] as num?) ?? 0).toDouble(),
          available: (c['available'] as bool?) ?? false,
        ),
        ram: RamStatus(
          usedMb: (r['usedMb'] as int?) ?? 0,
          totalMb: (r['totalMb'] as int?) ?? 0,
          available: (r['available'] as bool?) ?? false,
        ),
        screen: ScreenStatus(
          locked: (s['locked'] as bool?) ?? false,
          available: (s['available'] as bool?) ?? false,
        ),
        disk: DiskStatus(
          usedBytes: (d['usedBytes'] as int?) ?? 0,
          totalBytes: (d['totalBytes'] as int?) ?? 0,
          available: (d['available'] as bool?) ?? false,
        ),
      );
    } catch (_) {
      return ControlStatus.unavailable();
    }
  }

  @override
  Future<void> setVolume(int level) async {
    try { await _channel.invokeMethod('setVolume', {'level': level}); } catch (_) {}
  }

  @override
  Future<void> setMute(bool muted) async {
    try { await _channel.invokeMethod('setMute', {'muted': muted}); } catch (_) {}
  }

  @override
  Future<void> lockScreen() async {
    try { await _channel.invokeMethod('lockScreen'); } catch (_) {}
  }

  @override
  Future<void> wakeScreen() async {
    try { await _channel.invokeMethod('wakeScreen'); } catch (_) {}
  }

  @override
  Future<ClipboardStatus> getClipboard() async {
    try {
      final map = await _channel.invokeMethod<Map>('getClipboard');
      if (map == null) return ClipboardStatus.unavailable();
      return ClipboardStatus(
        text: (map['text'] as String?) ?? '',
        format: (map['format'] as String?) ?? 'text',
        available: (map['available'] as bool?) ?? false,
      );
    } catch (_) {
      return ClipboardStatus.unavailable();
    }
  }

  @override
  Future<AppLauncherStatus> getApps(List<LauncherApp> configured) async {
    try {
      final apps = configured.map((a) => a.toJson()).toList();
      final map = await _channel.invokeMethod<Map>('getApps', {'apps': apps});
      if (map == null) return AppLauncherStatus.unavailable();
      final appsList = (map['apps'] as List?)
          ?.map((e) => LauncherAppInfo.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList() ?? [];
      return AppLauncherStatus(
        apps: appsList,
        available: (map['available'] as bool?) ?? false,
      );
    } catch (_) {
      return AppLauncherStatus.unavailable();
    }
  }

  @override
  Future<void> launchApp(String executablePath) async {
    try { await _channel.invokeMethod('launchApp', {'path': executablePath}); } catch (_) {}
  }
}
