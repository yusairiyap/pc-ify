import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_providers.dart';

class ServerInfoCard extends ConsumerWidget {
  const ServerInfoCard({super.key, required this.hasBg});
  final bool hasBg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(serverInfoProvider);
    final statusAsync = ref.watch(controlStatusProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isConnected = statusAsync.hasValue && !statusAsync.hasError;

    return infoAsync.when(
      loading: () => _ServerInfoContent(
        serverName: '—',
        osVersion: '—',
        platform: 'unknown',
        isConnected: false,
        hasBg: hasBg,
        cs: cs,
        tt: tt,
      ),
      error: (_, __) => _ServerInfoContent(
        serverName: 'Offline',
        osVersion: '—',
        platform: 'unknown',
        isConnected: false,
        hasBg: hasBg,
        cs: cs,
        tt: tt,
      ),
      data: (info) => _ServerInfoContent(
        serverName: info?.serverName ?? '—',
        osVersion: info?.osVersion ?? '—',
        platform: info?.platform ?? 'unknown',
        isConnected: isConnected,
        hasBg: hasBg,
        cs: cs,
        tt: tt,
      ),
    );
  }
}

class _ServerInfoContent extends StatelessWidget {
  const _ServerInfoContent({
    required this.serverName,
    required this.osVersion,
    required this.platform,
    required this.isConnected,
    required this.hasBg,
    required this.cs,
    required this.tt,
  });

  final String serverName;
  final String osVersion;
  final String platform;
  final bool isConnected;
  final bool hasBg;
  final ColorScheme cs;
  final TextTheme tt;

  IconData _platformIcon() {
    return switch (platform.toLowerCase()) {
      'android' => Icons.phone_android,
      'macos' => Icons.laptop_mac,
      'windows' => Icons.computer,
      _ => Icons.dns,
    };
  }

  @override
  Widget build(BuildContext context) {
    final textColor = hasBg ? Colors.white : cs.onSurface;
    final subColor = hasBg ? Colors.white70 : cs.onSurfaceVariant;

    return Card(
      elevation: hasBg ? 0 : 1,
      color: hasBg ? Colors.black26 : cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(_platformIcon(), size: 48, color: cs.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serverName,
                    style: tt.titleMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    osVersion,
                    style: tt.bodySmall?.copyWith(color: subColor),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: isConnected ? Colors.green : cs.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConnected ? 'Connected' : 'Disconnected',
                        style: tt.labelSmall?.copyWith(
                          color: isConnected ? Colors.green : cs.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
