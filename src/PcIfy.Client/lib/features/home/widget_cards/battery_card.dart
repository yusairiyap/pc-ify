import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_providers.dart';

class BatteryCard extends ConsumerWidget {
  const BatteryCard({super.key, required this.hasBg});
  final bool hasBg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(controlStatusProvider);
    final cs = Theme.of(context).colorScheme;
    return statusAsync.when(
      loading: () => _BatteryCardContent(level: 0, charging: false, available: false, hasBg: hasBg, cs: cs),
      error: (_, __) => _BatteryCardContent(level: 0, charging: false, available: false, hasBg: hasBg, cs: cs),
      data: (status) => _BatteryCardContent(
        level: status.battery.level,
        charging: status.battery.charging,
        available: status.battery.available,
        hasBg: hasBg, cs: cs,
      ),
    );
  }
}

class _BatteryCardContent extends StatelessWidget {
  const _BatteryCardContent({
    required this.level, required this.charging,
    required this.available, required this.hasBg, required this.cs,
  });
  final int level; final bool charging; final bool available;
  final bool hasBg; final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: hasBg ? Colors.black45 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                charging ? Icons.battery_charging_full : _batteryIcon(level),
                color: hasBg ? Colors.white70 : cs.primary, size: 18,
              ),
              const SizedBox(width: 6),
              Text('Battery',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: hasBg ? Colors.white70 : cs.onSurfaceVariant,
                  )),
            ]),
            const SizedBox(height: 8),
            if (!available)
              Text('—', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                  color: hasBg ? Colors.white54 : cs.outline))
            else ...[
              Text('$level%',
                  style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold,
                    color: hasBg ? Colors.white : cs.onSurface,
                  )),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: level / 100,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  level < 20 ? Colors.red : (charging ? Colors.green : cs.primary),
                ),
              ),
              if (charging) ...[
                const SizedBox(height: 4),
                Text('Charging',
                    style: TextStyle(fontSize: 11,
                        color: hasBg ? Colors.greenAccent : Colors.green)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  IconData _batteryIcon(int level) {
    if (level >= 90) return Icons.battery_full;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 40) return Icons.battery_3_bar;
    if (level >= 20) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }
}
