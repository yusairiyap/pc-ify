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

  // Same header row pattern as Battery/CPU/RAM/Volume:
  // [icon 18px, "Server" label, Spacer, badge]
  Widget _headerRow(Color iconColor, Color labelColor) => Row(children: [
        Icon(_platformIcon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Text('Server', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
        const Spacer(),
        if (badge != null) badge!,
      ]);

  Widget _statusDot() => Row(
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

  @override
  Widget build(BuildContext context) {
    final iconColor  = hasBg ? Colors.white70 : cs.primary;
    final labelColor = hasBg ? Colors.white70 : cs.onSurfaceVariant;
    final textColor  = hasBg ? Colors.white   : cs.onSurface;
    final subColor   = hasBg ? Colors.white54 : cs.outline;

    // 2×2: tall, half-width — big centered icon below shared header
    if (size.isTall && !size.isWide) {
      return Card(
        color: hasBg ? Colors.black45 : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerRow(iconColor, labelColor),
              const Spacer(),
              Center(child: Icon(_platformIcon, size: 44, color: iconColor)),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  serverName,
                  style: tt.titleMedium?.copyWith(color: textColor, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 2),
              Center(
                child: Text(
                  osVersion,
                  style: tt.bodySmall?.copyWith(color: subColor),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              Center(child: _statusDot()),
            ],
          ),
        ),
      );
    }

    // 4×2: tall, full-width — header then expanded horizontal content
    if (size.isTall && size.isWide) {
      return Card(
        color: hasBg ? Colors.black45 : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerRow(iconColor, labelColor),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(_platformIcon, size: 56, color: iconColor),
                    const SizedBox(width: 16),
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
                          const SizedBox(height: 10),
                          _statusDot(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2×1: compact — shared header then server name + status
    if (!size.isWide) {
      return Card(
        color: hasBg ? Colors.black45 : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerRow(iconColor, labelColor),
              const SizedBox(height: 8),
              Text(
                serverName,
                style: tt.titleSmall?.copyWith(color: textColor, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              _statusDot(),
            ],
          ),
        ),
      );
    }

    // 4×1 (default fullWidth): shared header then horizontal content row
    return Card(
      color: hasBg ? Colors.black45 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerRow(iconColor, labelColor),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(_platformIcon, size: 36, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serverName,
                        style: tt.titleSmall?.copyWith(color: textColor, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        osVersion,
                        style: tt.bodySmall?.copyWith(color: subColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _statusDot(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
