import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/dashboard_models.dart';
import '../../../providers/dashboard_providers.dart';

class RamCard extends ConsumerStatefulWidget {
  const RamCard({super.key, required this.hasBg, required this.size});
  final bool hasBg;
  final WidgetSize size;

  @override
  ConsumerState<RamCard> createState() => _RamCardState();
}

class _RamCardState extends ConsumerState<RamCard> {
  bool _showAvailable = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (usedMb, totalMb, available) = ref.watch(controlStatusProvider).when(
      loading: () => (0, 0, false),
      error: (_, __) => (0, 0, false),
      data: (s) => (s.ram.usedMb, s.ram.totalMb, s.ram.available),
    );
    final availMb = totalMb - usedMb;
    final pct = totalMb > 0 ? usedMb / totalMb : 0.0;
    final displayMb = _showAvailable ? availMb : usedMb;
    final swapLabel = _showAvailable ? 'available' : 'used';

    final iconColor = widget.hasBg ? Colors.white70 : cs.primary;
    final labelColor = widget.hasBg ? Colors.white70 : cs.onSurfaceVariant;
    final valueColor = widget.hasBg ? Colors.white : cs.onSurface;
    final subColor = widget.hasBg ? Colors.white54 : cs.outline;
    final barColor = !_showAvailable && pct > 0.9
        ? Colors.red
        : (!_showAvailable && pct > 0.7 ? Colors.orange : cs.primary);
    final barValue = (_showAvailable ? (1.0 - pct) : pct).clamp(0.0, 1.0);

    if (widget.size.isTall) {
      return Card(
        color: widget.hasBg ? Colors.black45 : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: available ? () => setState(() => _showAvailable = !_showAvailable) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.storage_outlined, color: iconColor, size: 18),
                  const SizedBox(width: 6),
                  Text('RAM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
                  if (available) ...[
                    const Spacer(),
                    Icon(Icons.swap_horiz_outlined, size: 14, color: widget.hasBg ? Colors.white38 : cs.outline),
                  ],
                ]),
                const Spacer(),
                if (!available)
                  Center(child: Text('—', style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: subColor)))
                else
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_toGb(displayMb)} GB',
                          style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: valueColor),
                        ),
                        Text(
                          '$swapLabel · ${_toGb(totalMb)} GB total',
                          style: TextStyle(fontSize: 11, color: subColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                if (available) ...[
                  LinearProgressIndicator(
                    value: barValue,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}% used · tap to swap',
                    style: TextStyle(fontSize: 10, color: subColor),
                  ),
                ] else
                  const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );
    }

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
                Icon(Icons.storage_outlined, color: iconColor, size: 18),
                const SizedBox(width: 6),
                Text('RAM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
                if (available) ...[
                  const Spacer(),
                  Icon(Icons.swap_horiz_outlined, size: 14, color: widget.hasBg ? Colors.white38 : cs.outline),
                ],
              ]),
              const SizedBox(height: 8),
              if (!available)
                Text('—', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: subColor))
              else ...[
                Text(
                  '${_toGb(displayMb)} / ${_toGb(totalMb)} GB',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: barValue,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}% used · tap to show $swapLabel',
                  style: TextStyle(fontSize: 10, color: subColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _toGb(int mb) => (mb / 1024).toStringAsFixed(1);
}
