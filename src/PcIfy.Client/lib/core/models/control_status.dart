class BatteryStatus {
  const BatteryStatus({required this.level, required this.charging, required this.available});
  final int level;
  final bool charging;
  final bool available;
  factory BatteryStatus.unavailable() => const BatteryStatus(level: 0, charging: false, available: false);
  factory BatteryStatus.fromJson(Map<String, dynamic> j) => BatteryStatus(
    level: (j['level'] as num?)?.toInt() ?? 0,
    charging: (j['charging'] as bool?) ?? false,
    available: (j['available'] as bool?) ?? false,
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

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.text,
    required this.appName,
    required this.timestamp,
  });
  final String id;
  final String title;
  final String text;
  final String appName;
  final int timestamp;
  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
    id: (j['id'] as String?) ?? '',
    title: (j['title'] as String?) ?? '',
    text: (j['text'] as String?) ?? '',
    appName: (j['appName'] as String?) ?? '',
    timestamp: (j['timestamp'] as num?)?.toInt() ?? 0,
  );
}

class ControlStatus {
  const ControlStatus({
    required this.battery,
    required this.volume,
    required this.cpu,
    required this.ram,
    required this.screen,
  });
  final BatteryStatus battery;
  final VolumeStatus volume;
  final CpuStatus cpu;
  final RamStatus ram;
  final ScreenStatus screen;

  factory ControlStatus.unavailable() => ControlStatus(
    battery: BatteryStatus.unavailable(),
    volume: VolumeStatus.unavailable(),
    cpu: CpuStatus.unavailable(),
    ram: RamStatus.unavailable(),
    screen: ScreenStatus.unavailable(),
  );

  factory ControlStatus.fromJson(Map<String, dynamic> j) => ControlStatus(
    battery: BatteryStatus.fromJson(j['battery'] as Map<String, dynamic>? ?? {}),
    volume: VolumeStatus.fromJson(j['volume'] as Map<String, dynamic>? ?? {}),
    cpu: CpuStatus.fromJson(j['cpu'] as Map<String, dynamic>? ?? {}),
    ram: RamStatus.fromJson(j['ram'] as Map<String, dynamic>? ?? {}),
    screen: ScreenStatus.fromJson(j['screen'] as Map<String, dynamic>? ?? {}),
  );
}
