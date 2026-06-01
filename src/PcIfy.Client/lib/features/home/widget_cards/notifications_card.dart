import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/control_status.dart';
import '../../../providers/dashboard_providers.dart';

class NotificationsCard extends ConsumerWidget {
  const NotificationsCard({super.key, required this.hasBg});
  final bool hasBg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationsProvider);
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: hasBg ? Colors.black45 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.notifications_outlined,
                  color: hasBg ? Colors.white70 : cs.primary, size: 18),
              const SizedBox(width: 6),
              Text('Notifications',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: hasBg ? Colors.white70 : cs.onSurfaceVariant,
                  )),
              const Spacer(),
              // Refresh button
              SizedBox(
                width: 28, height: 28,
                child: IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  padding: EdgeInsets.zero,
                  color: hasBg ? Colors.white54 : cs.onSurfaceVariant,
                  onPressed: () => ref.read(notificationsProvider.notifier).refresh(),
                ),
              ),
              const SizedBox(width: 4),
              // Clear all
              notifAsync.maybeWhen(
                data: (r) => r.available && r.items.isNotEmpty
                    ? TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: hasBg ? Colors.white70 : null,
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => ref.read(notificationsProvider.notifier).clearAll(),
                        child: const Text('Clear all', style: TextStyle(fontSize: 12)),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
            ]),
            const SizedBox(height: 8),
            notifAsync.when(
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(strokeWidth: 2))),
              error: (_, __) => _unavailableText(cs, hasBg),
              data: (result) {
                if (!result.available) return _unavailableText(cs, hasBg);
                if (result.items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No notifications',
                        style: TextStyle(
                          fontSize: 13,
                          color: hasBg ? Colors.white38 : cs.outline,
                        )),
                  );
                }
                final shown = result.items.take(5).toList();
                return Column(
                  children: shown
                      .map((n) => _NotifTile(n: n, hasBg: hasBg, cs: cs))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _unavailableText(ColorScheme cs, bool hasBg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      'Not supported on this server platform',
      style: TextStyle(
        fontSize: 12,
        color: hasBg ? Colors.white38 : cs.outline,
      ),
    ),
  );
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.n, required this.hasBg, required this.cs});
  final NotificationItem n;
  final bool hasBg;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications, size: 16,
              color: hasBg ? Colors.white38 : cs.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(n.appName.isNotEmpty ? n.appName : 'App',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: hasBg ? Colors.white54 : cs.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                if (n.title.isNotEmpty)
                  Text(n.title,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: hasBg ? Colors.white87 : cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                if (n.text.isNotEmpty)
                  Text(n.text,
                      style: TextStyle(
                        fontSize: 12,
                        color: hasBg ? Colors.white54 : cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
