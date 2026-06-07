import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/control_status.dart';
import '../../../core/models/dashboard_models.dart';
import '../../../providers/dashboard_providers.dart';

class ClipboardCard extends ConsumerWidget {
  const ClipboardCard({super.key, required this.hasBg, required this.size, this.badge});
  final bool hasBg;
  final WidgetSize size;
  final Widget? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final status = ref.watch(serverClipboardProvider).when(
      loading: () => PcClipboardStatus.unavailable(),
      error: (_, __) => PcClipboardStatus.unavailable(),
      data: (s) => s,
    );
    return _ClipboardBody(status: status, hasBg: hasBg, cs: cs, size: size, badge: badge);
  }
}

class _ClipboardBody extends StatelessWidget {
  const _ClipboardBody({
    required this.status,
    required this.hasBg,
    required this.cs,
    required this.size,
    this.badge,
  });
  final PcClipboardStatus status;
  final bool hasBg;
  final ColorScheme cs;
  final WidgetSize size;
  final Widget? badge;

  IconData get _formatIcon => switch (status.format) {
    ClipboardFormat.clipUrl  => Icons.link,
    ClipboardFormat.clipCode => Icons.code,
    ClipboardFormat.clipText => Icons.text_fields,
  };

  String get _formatLabel => switch (status.format) {
    ClipboardFormat.clipUrl  => 'URL',
    ClipboardFormat.clipCode => 'Code',
    ClipboardFormat.clipText => 'Text',
  };

  void _copyToPhone(BuildContext context) {
    Clipboard.setData(ClipboardData(text: status.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to phone!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = hasBg ? Colors.white70 : cs.primary;
    final labelColor = hasBg ? Colors.white70 : cs.onSurfaceVariant;
    final textColor = hasBg ? Colors.white : cs.onSurface;
    final subColor = hasBg ? Colors.white54 : cs.outline;

    final previewLines = status.text.split('\n').take(3).join('\n');
    final hasContent = status.available && status.text.isNotEmpty;

    return Card(
      color: hasBg ? Colors.black45 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.content_paste, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text('Clipboard',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
              if (hasContent) ...[
                const SizedBox(width: 6),
                Icon(_formatIcon, size: 13, color: subColor),
                const SizedBox(width: 2),
                Text(_formatLabel, style: TextStyle(fontSize: 11, color: subColor)),
              ],
              const Spacer(),
              if (badge != null) badge!,
            ]),
            const SizedBox(height: 8),
            if (!status.available)
              Text(
                'Not available on this platform',
                style: TextStyle(fontSize: 13, color: subColor, fontStyle: FontStyle.italic),
              )
            else if (!hasContent)
              Text(
                'Nothing in clipboard',
                style: TextStyle(fontSize: 13, color: subColor, fontStyle: FontStyle.italic),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      previewLines,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor,
                        fontFamily:
                            status.format == ClipboardFormat.clipCode ? 'monospace' : null,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    width: 36,
                    child: FloatingActionButton.small(
                      heroTag: 'clipboard_copy',
                      onPressed: () => _copyToPhone(context),
                      backgroundColor:
                          hasBg ? Colors.white24 : cs.primaryContainer,
                      foregroundColor:
                          hasBg ? Colors.white : cs.onPrimaryContainer,
                      elevation: 1,
                      child: const Icon(Icons.phone_iphone, size: 18),
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
