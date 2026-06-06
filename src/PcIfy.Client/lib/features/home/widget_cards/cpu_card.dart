import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/dashboard_models.dart';
import '../../../providers/dashboard_providers.dart';

class CpuCard extends ConsumerWidget {
  const CpuCard({super.key, required this.hasBg, required this.size});
  final bool hasBg;
  final WidgetSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final (usage, available) = ref.watch(controlStatusProvider).when(
      loading: () => (0.0, false),
      error: (_, __) => (0.0, false),
      data: (s) => (s.cpu.usage, s.cpu.available),
    );

    final iconColor = hasBg ? Colors.white70 : cs.primary;
    final labelColor = hasBg ? Colors.white70 : cs.onSurfaceVariant;
    final valueColor = hasBg ? Colors.white : cs.onSurface;
    final subColor = hasBg ? Colors.white54 : cs.outline;
    final barColor = usage > 80 ? Colors.red : (usage > 60 ? Colors.orange : cs.primary);
    final valueText = available ? '${usage.toStringAsFixed(1)}%' : '—';

    if (size.isTall) {
      return Card(
        color: hasBg ? Colors.black45 : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.memory_outlined, color: iconColor, size: 18),
                const SizedBox(width: 6),
                Text('CPU', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
              ]),
              const Spacer(),
              Center(
                child: Text(
                  valueText,
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: available ? valueColor : subColor,
                  ),
                ),
              ),
              const Spacer(),
              if (available) ...[
                LinearProgressIndicator(
                  value: (usage / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
                const SizedBox(height: 6),
                Text('CPU usage', style: TextStyle(fontSize: 10, color: subColor)),
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
              Icon(Icons.memory_outlined, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text('CPU', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
            ]),
            const SizedBox(height: 8),
            if (!available)
              Text('—', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: subColor))
            else ...[
              Text(valueText, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: valueColor)),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (usage / 100).clamp(0.0, 1.0),
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
