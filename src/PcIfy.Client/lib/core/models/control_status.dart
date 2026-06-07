class BatteryStatus {
  const BatteryStatus({
    required this.level,
    required this.charging,
    required this.available,
    this.temperatureCelsius = 0,
    this.temperatureAvailable = false,
  });
  final int level;
  final bool charging;
  final bool available;
  final int temperatureCelsius;
  final bool temperatureAvailable;
  factory BatteryStatus.unavailable() => const BatteryStatus(level: 0, charging: false, available: false);
  factory BatteryStatus.fromJson(Map<String, dynamic> j) => BatteryStatus(
    level: (j['level'] as num?)?.toInt() ?? 0,
    charging: (j['charging'] as bool?) ?? false,
    available: (j['available'] as bool?) ?? false,
    temperatureCelsius: (j['temperatureCelsius'] as num?)?.toInt() ?? 0,
    temperatureAvailable: (j['temperatureAvailable'] as bool?) ?? false,
  );
}

class VolumeStatus {
  const VolumeStatus({required this.level, required this.muted, required this.available});
  final int level;
  final bool muted;
  final bool available;
  factory VolumeStatus.unavailable() => const VolumeStatus(level: 50, muted: false, available: false);
  factory VolumeStatus.fromJson(Map<String, dynamic> j) => VolumeStatus(
    level: (j['level'] as num?)?.toInt() ?? 50,
    muted: (j['muted'] as bool?) ?? false,
    available: (j['available'] as bool?) ?? false,
  );
}

class CpuStatus {
  const CpuStatus({required this.usage, required this.available});
  final double usage;
  final bool available;
  factory CpuStatus.unavailable() => const CpuStatus(usage: 0, available: false);
  factory CpuStatus.fromJson(Map<String, dynamic> j) => CpuStatus(
    usage: (j['usage'] as num?)?.toDouble() ?? 0,
    available: (j['available'] as bool?) ?? false,
  );
}

class RamStatus {
  const RamStatus({required this.usedMb, required this.totalMb, required this.available});
  final int usedMb;
  final int totalMb;
  final bool available;
  factory RamStatus.unavailable() => const RamStatus(usedMb: 0, totalMb: 0, available: false);
  factory RamStatus.fromJson(Map<String, dynamic> j) => RamStatus(
    usedMb: (j['usedMb'] as num?)?.toInt() ?? 0,
    totalMb: (j['totalMb'] as num?)?.toInt() ?? 0,
    available: (j['available'] as bool?) ?? false,
  );
}

class ScreenStatus {
  const ScreenStatus({required this.locked, required this.available});
  final bool locked;
  final bool available;
  factory ScreenStatus.unavailable() => const ScreenStatus(locked: false, available: false);
  factory ScreenStatus.fromJson(Map<String, dynamic> j) => ScreenStatus(
    locked: (j['locked'] as bool?) ?? false,
    available: (j['available'] as bool?) ?? false,
  );
}

class DiskStatus {
  const DiskStatus({required this.usedBytes, required this.totalBytes, required this.available});
  final int usedBytes;
  final int totalBytes;
  final bool available;
  factory DiskStatus.unavailable() => const DiskStatus(usedBytes: 0, totalBytes: 0, available: false);
  factory DiskStatus.fromJson(Map<String, dynamic> j) => DiskStatus(
    usedBytes: (j['usedBytes'] as num?)?.toInt() ?? 0,
    totalBytes: (j['totalBytes'] as num?)?.toInt() ?? 0,
    available: (j['available'] as bool?) ?? false,
  );
}

class ControlStatus {
  const ControlStatus({
    required this.battery,
    required this.volume,
    required this.cpu,
    required this.ram,
    required this.screen,
    required this.disk,
  });
  final BatteryStatus battery;
  final VolumeStatus volume;
  final CpuStatus cpu;
  final RamStatus ram;
  final ScreenStatus screen;
  final DiskStatus disk;

  factory ControlStatus.unavailable() => ControlStatus(
    battery: BatteryStatus.unavailable(),
    volume: VolumeStatus.unavailable(),
    cpu: CpuStatus.unavailable(),
    ram: RamStatus.unavailable(),
    screen: ScreenStatus.unavailable(),
    disk: DiskStatus.unavailable(),
  );

  factory ControlStatus.fromJson(Map<String, dynamic> j) => ControlStatus(
    battery: BatteryStatus.fromJson(j['battery'] as Map<String, dynamic>? ?? {}),
    volume: VolumeStatus.fromJson(j['volume'] as Map<String, dynamic>? ?? {}),
    cpu: CpuStatus.fromJson(j['cpu'] as Map<String, dynamic>? ?? {}),
    ram: RamStatus.fromJson(j['ram'] as Map<String, dynamic>? ?? {}),
    screen: ScreenStatus.fromJson(j['screen'] as Map<String, dynamic>? ?? {}),
    disk: DiskStatus.fromJson(j['disk'] as Map<String, dynamic>? ?? {}),
  );
}

// ── Clipboard ─────────────────────────────────────────────────────────────────

enum ClipboardFormat { clipText, clipUrl, clipCode }

class PcClipboardStatus {
  const PcClipboardStatus({required this.text, required this.format, required this.available});
  final String text;
  final ClipboardFormat format;
  final bool available;

  factory PcClipboardStatus.unavailable() =>
      const PcClipboardStatus(text: '', format: ClipboardFormat.clipText, available: false);

  factory PcClipboardStatus.fromJson(Map<String, dynamic> j) {
    final fmtStr = j['format'] as String? ?? 'text';
    final fmt = switch (fmtStr) {
      'url' => ClipboardFormat.clipUrl,
      'code' => ClipboardFormat.clipCode,
      _ => ClipboardFormat.clipText,
    };
    return PcClipboardStatus(
      text: (j['text'] as String?) ?? '',
      format: fmt,
      available: (j['available'] as bool?) ?? false,
    );
  }
}

// ── App Launcher ──────────────────────────────────────────────────────────────

class LauncherAppInfo {
  const LauncherAppInfo({required this.id, required this.name, this.iconKey, required this.running});
  final String id;
  final String name;
  final String? iconKey;
  final bool running;

  factory LauncherAppInfo.fromJson(Map<String, dynamic> j) => LauncherAppInfo(
    id: (j['id'] as String?) ?? '',
    name: (j['name'] as String?) ?? '',
    iconKey: j['iconKey'] as String?,
    running: (j['running'] as bool?) ?? false,
  );
}

class AppLauncherStatus {
  const AppLauncherStatus({required this.apps, required this.available});
  final List<LauncherAppInfo> apps;
  final bool available;

  factory AppLauncherStatus.unavailable() =>
      const AppLauncherStatus(apps: [], available: false);

  factory AppLauncherStatus.fromJson(Map<String, dynamic> j) => AppLauncherStatus(
    apps: (j['apps'] as List<dynamic>? ?? [])
        .map((e) => LauncherAppInfo.fromJson(e as Map<String, dynamic>))
        .toList(),
    available: (j['available'] as bool?) ?? false,
  );
}
