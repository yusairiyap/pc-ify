import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/dashboard_models.dart';
import '../../../providers/dashboard_providers.dart';

class BatteryCard extends ConsumerWidget {
  const BatteryCard({super.key, required this.hasBg, required this.size, this.badge});
  final bool hasBg;
  final WidgetSize size;
  final Widget? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return ref.watch(controlStatusProvider).when(
      loading: () => _BatteryBody(level: 0, charging: false, available: false, hasBg: hasBg, cs: cs, size: size, badge: badge),
      error: (_, __) => _BatteryBody(level: 0, charging: false, available: false, hasBg: hasBg, cs: cs, size: size, badge: badge),
      data: (s) => _BatteryBody(
        level: s.battery.level, charging: s.battery.charging,
        available: s.battery.available, hasBg: hasBg, cs: cs, size: size, badge: badge,
      ),
    );
  }
}

class _BatteryBody extends StatelessWidget {
  const _BatteryBody({
    required this.level, required this.charging, required this.available,
    required this.hasBg, required this.cs, required this.size, this.badge,
  });
  final int level;
  final bool charging;
  final bool available;
  final bool hasBg;
  final ColorScheme cs;
  final WidgetSize size;
  final Widget? badge;

  Color get _barColor => level < 20 ? Colors.red : (charging ? Colors.green : cs.primary);

  IconData _icon() {
    if (charging) return Icons.battery_charging_full;
    if (level >= 90) return Icons.battery_full;
    if (level >= 60) return Icons.battery_5_bar;
    if (level >= 40) return Icons.battery_3_bar;
    if (level >= 20) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = hasBg ? Colors.white70 : cs.primary;
    final labelColor = hasBg ? Colors.white70 : cs.onSurfaceVariant;
    final valueColor = hasBg ? Colors.white : cs.onSurface;
    final subColor = hasBg ? Colors.white54 : cs.outline;

    if (size.isTall) {
      return Card(
        color: hasBg ? Colors.black45 : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(_icon(), color: iconColor, size: 18),
                const SizedBox(width: 6),
                Text('Battery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
                if (charging || badge != null) const Spacer(),
                if (charging) _ChargingChip(hasBg: hasBg),
                if (charging && badge != null) const SizedBox(width: 4),
                if (badge != null) badge!,
              ]),
              const Spacer(),
              Center(
                child: Text(
                  available ? '$level%' : '—',
                  style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold,
                      color: available ? valueColor : subColor),
                ),
              ),
              const Spacer(),
              if (available) ...[
                LinearProgressIndicator(
                  value: level / 100,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(_barColor),
                ),
                const SizedBox(height: 6),
                Text(
                  charging ? 'Charging' : 'Battery level',
                  style: TextStyle(fontSize: 10, color: subColor),
                ),
              ] else
                const SizedBox(height: 12),
            ],
          ),
        ),
      );
    }

    return Card(
      color: hasBg ? Colors.black45 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_icon(), color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text('Battery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
              if (badge != null) ...[const Spacer(), badge!],
            ]),
            const SizedBox(height: 8),
            if (!available)
              Text('—', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: subColor))
            else ...[
              Text('$level%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: valueColor)),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: level / 100,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(_barColor),
              ),
              if (charging) ...[
                const SizedBox(height: 4),
                Text('Charging', style: TextStyle(fontSize: 11, color: hasBg ? Colors.greenAccent : Colors.green)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ChargingChip extends StatelessWidget {
  const _ChargingChip({required this.hasBg});
  final bool hasBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: hasBg ? 0.3 : 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bolt, size: 10, color: hasBg ? Colors.greenAccent : Colors.green),
        const SizedBox(width: 2),
        Text('Charging',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: hasBg ? Colors.greenAccent : Colors.green,
            )),
      ]),
    );
  }
}
