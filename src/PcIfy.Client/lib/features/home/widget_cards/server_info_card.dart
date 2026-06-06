import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/dashboard_models.dart';
import '../../../providers/dashboard_providers.dart';

class ServerInfoCard extends ConsumerWidget {
  const ServerInfoCard({super.key, required this.hasBg, required this.size, this.badge});
  final bool hasBg;
  final WidgetSize size;
  final Widget? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isConnected = ref.watch(controlStatusProvider).maybeWhen(
      data: (_) => true,
      orElse: () => false,
    );
    return ref.watch(serverInfoProvider).when(
      loading: () => _ServerInfoBody(serverName: '—', osVersion: '—', platform: 'unknown', isConnected: false, hasBg: hasBg, cs: cs, tt: tt, size: size, badge: badge),
      error: (_, __) => _ServerInfoBody(serverName: 'Offline', osVersion: '—', platform: 'unknown', isConnected: false, hasBg: hasBg, cs: cs, tt: tt, size: size, badge: badge),
      data: (info) => _ServerInfoBody(
        serverName: info?.serverName ?? '—',
        osVersion: info?.osVersion ?? '—',
        platform: info?.platform ?? 'unknown',
        isConnected: isConnected,
        hasBg: hasBg, cs: cs, tt: tt, size: size, badge: badge,
      ),
    );
  }
}

class _ServerInfoBody extends StatelessWidget {
  const _ServerInfoBody({
    required this.serverName, required this.osVersion, required this.platform,
    required this.isConnected, required this.hasBg,
    required this.cs, required this.tt, required this.size, this.badge,
  });
  final String serverName;
  final String osVersion;
  final String platform;
  final bool isConnected;
  final bool hasBg;
  final ColorScheme cs;
  final TextTheme tt;
  final WidgetSize size;
  final Widget? badge;

  IconData get _platformIcon => switch (platform.toLowerCase()) {
        'android' => Icons.phone_android,
        'macos' => Icons.laptop_mac,
        'windows' => Icons.computer,
        _ => Icons.dns,
      };

  Widget _statusRow() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: isConnected ? Colors.green : cs.error),
          const SizedBox(width: 4),
          Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: tt.labelSmall?.copyWith(color: isConnected ? Colors.green : cs.error),
          ),
        ],
      );

  // Badge is overlaid top-right since ServerInfo has no traditional header row.
  Widget _withBadge(Widget card) {
    if (badge == null) return card;
    return Stack(
      children: [
        card,
        Positioned(top: 8, right: 8, child: badge!),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = hasBg ? Colors.white : cs.onSurface;
    final subColor = hasBg ? Colors.white70 : cs.onSurfaceVariant;
    final cardColor = hasBg ? Colors.black26 : cs.surfaceContainerLow;

    // 2×2: vertical centered layout
    if (size.isTall && !size.isWide) {
      return _withBadge(Card(
        elevation: hasBg ? 0 : 1,
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Icon(_platformIcon, size: 52, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                serverName,
                style: tt.titleMedium?.copyWith(color: textColor, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                osVersion,
                style: tt.bodySmall?.copyWith(color: subColor),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              _statusRow(),
            ],
          ),
        ),
      ));
    }

    // 4×2: horizontal layout with larger elements and extra breathing room
    if (size.isTall && size.isWide) {
      return _withBadge(Card(
        elevation: hasBg ? 0 : 1,
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(_platformIcon, size: 72, color: cs.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      serverName,
                      style: tt.headlineSmall?.copyWith(color: textColor, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      osVersion,
                      style: tt.bodyMedium?.copyWith(color: subColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    _statusRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
    }

    // 2×1: compact, icon + name + status
    if (!size.isWide) {
      return _withBadge(Card(
        elevation: hasBg ? 0 : 1,
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(_platformIcon, size: 32, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serverName,
                      style: tt.labelLarge?.copyWith(color: textColor, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _statusRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
    }

    // 4×1 (default): original horizontal layout
    return _withBadge(Card(
      elevation: hasBg ? 0 : 1,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(_platformIcon, size: 48, color: cs.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serverName,
                    style: tt.titleMedium?.copyWith(color: textColor, fontWeight: FontWeight.w600),
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
                  _statusRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
