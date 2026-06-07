import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/dashboard_models.dart';
import '../../../providers/dashboard_providers.dart';

class DiskCard extends ConsumerStatefulWidget {
  const DiskCard({super.key, required this.hasBg, required this.size, this.badge});
  final bool hasBg;
  final WidgetSize size;
  final Widget? badge;

  @override
  ConsumerState<DiskCard> createState() => _DiskCardState();
}

class _DiskCardState extends ConsumerState<DiskCard> {
  bool _showFree = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (usedBytes, totalBytes, available) = ref.watch(controlStatusProvider).when(
      loading: () => (0, 0, false),
      error: (_, __) => (0, 0, false),
      data: (s) => (s.disk.usedBytes, s.disk.totalBytes, s.disk.available),
    );
    final freeBytes = totalBytes - usedBytes;
    final pct = totalBytes > 0 ? usedBytes / totalBytes : 0.0;
    final displayBytes = _showFree ? freeBytes : usedBytes;
    final swapLabel = _showFree ? 'free' : 'used';

    final iconColor = widget.hasBg ? Colors.white70 : cs.primary;
    final labelColor = widget.hasBg ? Colors.white70 : cs.onSurfaceVariant;
    final valueColor = widget.hasBg ? Colors.white : cs.onSurface;
    final subColor = widget.hasBg ? Colors.white54 : cs.outline;
    final swapIconColor = widget.hasBg ? Colors.white38 : cs.outline;
    final barColor = !_showFree && pct > 0.9
        ? Colors.red
        : (!_showFree && pct > 0.7 ? Colors.orange : cs.primary);
    final barValue = (_showFree ? (1.0 - pct) : pct).clamp(0.0, 1.0);

    Widget headerRow() => Row(children: [
      Icon(Icons.disc_full_outlined, color: iconColor, size: 18),
      const SizedBox(width: 6),
      Text('Disk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
      const Spacer(),
      if (available) ...[
        Icon(Icons.swap_horiz_outlined, size: 14, color: swapIconColor),
        const SizedBox(width: 4),
      ],
      if (widget.badge != null) widget.badge!,
    ]);

    if (widget.size.isTall) {
      return Card(
        color: widget.hasBg ? Colors.black45 : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: available ? () => setState(() => _showFree = !_showFree) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerRow(),
                const Spacer(),
                if (!available)
                  Center(child: Text('—', style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: subColor)))
                else
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_toGb(displayBytes)} GB',
                          style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: valueColor),
                        ),
                        Text(
                          '$swapLabel · ${_toGb(totalBytes)} GB total',
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
        onTap: available ? () => setState(() => _showFree = !_showFree) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerRow(),
              const SizedBox(height: 8),
              if (!available)
                Text('—', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: subColor))
              else ...[
                Text(
                  '${_toGb(displayBytes)} / ${_toGb(totalBytes)} GB',
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

  String _toGb(int bytes) => (bytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
}
