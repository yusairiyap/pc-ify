import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_providers.dart';

class RamCard extends ConsumerStatefulWidget {
  const RamCard({super.key, required this.hasBg});
  final bool hasBg;

  @override
  ConsumerState<RamCard> createState() => _RamCardState();
}

class _RamCardState extends ConsumerState<RamCard> {
  bool _showAvailable = false;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(controlStatusProvider);
    final cs = Theme.of(context).colorScheme;
    final (usedMb, totalMb, available) = statusAsync.when(
      loading: () => (0, 0, false),
      error: (_, __) => (0, 0, false),
      data: (s) => (s.ram.usedMb, s.ram.totalMb, s.ram.available),
    );
    final availMb = totalMb - usedMb;
    final pct = totalMb > 0 ? usedMb / totalMb : 0.0;

    final displayMb = _showAvailable ? availMb : usedMb;
    final label = _showAvailable ? 'avail.' : 'used';

    return Card(
      color: widget.hasBg ? Colors.black45 : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: available ? () => setState(() => _showAvailable = !_showAvailable) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.storage_outlined,
                    color: widget.hasBg ? Colors.white70 : cs.primary, size: 18),
                const SizedBox(width: 6),
                Text('RAM',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: widget.hasBg ? Colors.white70 : cs.onSurfaceVariant,
                    )),
                if (available) ...[
                  const Spacer(),
                  Icon(Icons.swap_horiz_outlined,
                      size: 14,
                      color: widget.hasBg ? Colors.white38 : cs.outline),
                ],
              ]),
              const SizedBox(height: 8),
              if (!available)
                Text('—',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold,
                        color: widget.hasBg ? Colors.white54 : cs.outline))
              else ...[
                Text(
                  '${_toGb(displayMb)} / ${_toGb(totalMb)} GB',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: widget.hasBg ? Colors.white : cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: _showAvailable
                      ? (1.0 - pct).clamp(0.0, 1.0)
                      : pct.clamp(0.0, 1.0),
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    !_showAvailable && pct > 0.9
                        ? Colors.red
                        : (!_showAvailable && pct > 0.7
                            ? Colors.orange
                            : cs.primary),
                  ),
                ),
                const SizedBox(height: 2),
                Text('${(pct * 100).toStringAsFixed(0)}% used · tap to show $label',
                    style: TextStyle(
                      fontSize: 10,
                      color: widget.hasBg ? Colors.white54 : cs.outline,
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _toGb(int mb) => (mb / 1024).toStringAsFixed(1);
}
