// ── DTOs ─────────────────────────────────────────────────────────────────────

class BatteryStatus {
  const BatteryStatus({required this.level, required this.charging, required this.available});
  final int level;
  final bool charging;
  final bool available;
  Map<String, dynamic> toJson() => {'level': level, 'charging': charging, 'available': available};
  factory BatteryStatus.unavailable() => const BatteryStatus(level: 0, charging: false, available: false);
}

class VolumeStatus {
  const VolumeStatus({required this.level, required this.muted, required this.available});
  final int level;
  final bool muted;
  final bool available;
  Map<String, dynamic> toJson() => {'level': level, 'muted': muted, 'available': available};
  factory VolumeStatus.unavailable() => const VolumeStatus(level: 50, muted: false, available: false);
}

class CpuStatus {
  const CpuStatus({required this.usage, required this.available});
  final double usage;
  final bool available;
  Map<String, dynamic> toJson() => {'usage': usage, 'available': available};
  factory CpuStatus.unavailable() => const CpuStatus(usage: 0, available: false);
}

class RamStatus {
  const RamStatus({required this.usedMb, required this.totalMb, required this.available});
  final int usedMb;
  final int totalMb;
  final bool available;
  Map<String, dynamic> toJson() => {'usedMb': usedMb, 'totalMb': totalMb, 'available': available};
  factory RamStatus.unavailable() => const RamStatus(usedMb: 0, totalMb: 0, available: false);
}

class ScreenStatus {
  const ScreenStatus({required this.locked, required this.available});
  final bool locked;
  final bool available;
  Map<String, dynamic> toJson() => {'locked': locked, 'available': available};
  factory ScreenStatus.unavailable() => const ScreenStatus(locked: false, available: false);
}

class DiskStatus {
  const DiskStatus({required this.usedBytes, required this.totalBytes, required this.available});
  final int usedBytes;
  final int totalBytes;
  final bool available;
  Map<String, dynamic> toJson() => {'usedBytes': usedBytes, 'totalBytes': totalBytes, 'available': available};
  factory DiskStatus.unavailable() => const DiskStatus(usedBytes: 0, totalBytes: 0, available: false);
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

  Map<String, dynamic> toJson() => {
    'battery': battery.toJson(),
    'volume': volume.toJson(),
    'cpu': cpu.toJson(),
    'ram': ram.toJson(),
    'screen': screen.toJson(),
    'disk': disk.toJson(),
  };
}

// ── Abstract service ──────────────────────────────────────────────────────────

abstract class SystemControlService {
  Future<ControlStatus> getStatus();
  Future<void> setVolume(int level);
  Future<void> setMute(bool muted);
  Future<void> lockScreen();
  Future<void> wakeScreen();
}

// ── No-op fallback ────────────────────────────────────────────────────────────

class _NoOpSystemControlService implements SystemControlService {
  @override Future<ControlStatus> getStatus() async => ControlStatus.unavailable();
  @override Future<void> setVolume(int level) async {}
  @override Future<void> setMute(bool muted) async {}
  @override Future<void> lockScreen() async {}
  @override Future<void> wakeScreen() async {}
}

// ── Helper singleton ──────────────────────────────────────────────────────────

class SystemControlServiceHelper {
  static SystemControlService _instance = _NoOpSystemControlService();

  static void register(SystemControlService impl) => _instance = impl;
  static SystemControlService get instance => _instance;
}
