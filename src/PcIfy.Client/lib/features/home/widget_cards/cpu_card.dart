import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_providers.dart';

class CpuCard extends ConsumerWidget {
  const CpuCard({super.key, required this.hasBg});
  final bool hasBg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(controlStatusProvider);
    final cs = Theme.of(context).colorScheme;
    final (usage, available) = statusAsync.when(
      loading: () => (0.0, false),
      error: (_, __) => (0.0, false),
      data: (s) => (s.cpu.usage, s.cpu.available),
    );
    return Card(
      color: hasBg ? Colors.black45 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.memory_outlined,
                  color: hasBg ? Colors.white70 : cs.primary, size: 18),
              const SizedBox(width: 6),
              Text('CPU',
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
              Text('${usage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold,
                    color: hasBg ? Colors.white : cs.onSurface,
                  )),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (usage / 100).clamp(0.0, 1.0),
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  usage > 80 ? Colors.red : (usage > 60 ? Colors.orange : cs.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
