import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/dashboard_models.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/services_providers.dart';

class ScreenLockCard extends ConsumerWidget {
  const ScreenLockCard({super.key, required this.hasBg, required this.size});
  final bool hasBg;
  final WidgetSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final available = ref.watch(controlStatusProvider).when(
      loading: () => false,
      error: (_, __) => false,
      data: (s) => s.screen.available,
    );
    final iconColor = hasBg ? Colors.white70 : cs.primary;
    final labelColor = hasBg ? Colors.white70 : cs.onSurfaceVariant;
    final subColor = hasBg ? Colors.white38 : cs.outline;

    final lockBtn = Expanded(
      child: FilledButton.icon(
        icon: const Icon(Icons.lock_outline, size: 16),
        label: const Text('Lock'),
        style: FilledButton.styleFrom(
          backgroundColor: hasBg ? Colors.white24 : null,
          foregroundColor: hasBg ? Colors.white : null,
        ),
        onPressed: available ? () async { await ref.read(apiServiceProvider).lockScreen(); } : null,
      ),
    );
    final wakeBtn = Expanded(
      child: OutlinedButton.icon(
        icon: const Icon(Icons.brightness_high_outlined, size: 16),
        label: const Text('Wake'),
        style: OutlinedButton.styleFrom(
          foregroundColor: hasBg ? Colors.white70 : null,
          side: hasBg ? const BorderSide(color: Colors.white30) : null,
        ),
        onPressed: () async { await ref.read(apiServiceProvider).wakeScreen(); },
      ),
    );

    if (size.isTall) {
      return Card(
        color: hasBg ? Colors.black45 : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.lock_outline, color: iconColor, size: 18),
                const SizedBox(width: 6),
                Text('Screen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
              ]),
              const Spacer(),
              Center(
                child: Icon(
                  available ? Icons.lock_open_outlined : Icons.no_encryption_gmailerrorred_outlined,
                  size: 48,
                  color: available ? iconColor : subColor,
                ),
              ),
              const Spacer(),
              Row(children: [lockBtn, const SizedBox(width: 8), wakeBtn]),
              if (!available) ...[
                const SizedBox(height: 8),
                Text(
                  'Not available on this platform',
                  style: TextStyle(fontSize: 11, color: subColor),
                ),
              ],
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
              Icon(Icons.lock_outline, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text('Screen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
            ]),
            const SizedBox(height: 12),
            Row(children: [lockBtn, const SizedBox(width: 8), wakeBtn]),
            if (!available) ...[
              const SizedBox(height: 8),
              Text(
                'Screen lock is not available on this server platform',
                style: TextStyle(fontSize: 11, color: subColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
