import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/services_providers.dart';

class ScreenLockCard extends ConsumerWidget {
  const ScreenLockCard({super.key, required this.hasBg});
  final bool hasBg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(controlStatusProvider);
    final cs = Theme.of(context).colorScheme;
    final available = statusAsync.when(
      loading: () => false,
      error: (_, __) => false,
      data: (s) => s.screen.available,
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
              Icon(Icons.lock_outline,
                  color: hasBg ? Colors.white70 : cs.primary, size: 18),
              const SizedBox(width: 6),
              Text('Screen',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: hasBg ? Colors.white70 : cs.onSurfaceVariant,
                  )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.lock_outline, size: 16),
                  label: const Text('Lock'),
                  style: FilledButton.styleFrom(
                    backgroundColor: hasBg ? Colors.white24 : null,
                    foregroundColor: hasBg ? Colors.white : null,
                  ),
                  onPressed: available
                      ? () async {
                          await ref.read(apiServiceProvider).lockScreen();
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.brightness_high_outlined, size: 16),
                  label: const Text('Wake'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: hasBg ? Colors.white70 : null,
                    side: hasBg ? const BorderSide(color: Colors.white30) : null,
                  ),
                  onPressed: () async {
                    await ref.read(apiServiceProvider).wakeScreen();
                  },
                ),
              ),
            ]),
            if (!available)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Enable Accessibility Service on the server device: '
                  'Settings → Accessibility → pc-ify server',
                  style: TextStyle(
                    fontSize: 11,
                    color: hasBg ? Colors.white38 : cs.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
