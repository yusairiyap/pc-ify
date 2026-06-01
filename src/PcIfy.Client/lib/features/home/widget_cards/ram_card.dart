import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_providers.dart';

class RamCard extends ConsumerWidget {
  const RamCard({super.key, required this.hasBg});
  final bool hasBg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(controlStatusProvider);
    final cs = Theme.of(context).colorScheme;
    final (usedMb, totalMb, available) = statusAsync.when(
      loading: () => (0, 0, false),
      error: (_, __) => (0, 0, false),
      data: (s) => (s.ram.usedMb, s.ram.totalMb, s.ram.available),
    );
    final pct = totalMb > 0 ? usedMb / totalMb : 0.0;

    return Card(
      color: hasBg ? Colors.black45 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.storage_outlined,
                  color: hasBg ? Colors.white70 : cs.primary, size: 18),
              const SizedBox(width: 6),
              Text('RAM',
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
              Text(
                '${_toGb(usedMb)} / ${_toGb(totalMb)} GB',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold,
                  color: hasBg ? Colors.white : cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  pct > 0.9 ? Colors.red : (pct > 0.7 ? Colors.orange : cs.primary),
                ),
              ),
              const SizedBox(height: 2),
              Text('${(pct * 100).toStringAsFixed(0)}% used',
                  style: TextStyle(
                    fontSize: 10,
                    color: hasBg ? Colors.white54 : cs.outline,
                  )),
            ],
          ],
        ),
      ),
    );
  }

  String _toGb(int mb) => (mb / 1024).toStringAsFixed(1);
}
