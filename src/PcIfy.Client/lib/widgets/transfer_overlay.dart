import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/transfer_task.dart';
import '../core/utils/file_size_formatter.dart';
import '../providers/transfer_providers.dart';

class TransferOverlay extends ConsumerStatefulWidget {
  const TransferOverlay({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<TransferOverlay> createState() => _TransferOverlayState();
}

class _TransferOverlayState extends ConsumerState<TransferOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onStateChange(TransferState? prev, TransferState next) {
    final showing = next.panelVisible && !next.isMinimized;
    final wasShowing =
        prev != null && prev.panelVisible && !prev.isMinimized;
    if (showing && !wasShowing) {
      _ctrl.forward(from: 0.0);
    } else if (!showing && wasShowing) {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TransferState>(transferManagerProvider, _onStateChange);
    final state = ref.watch(transferManagerProvider);
    if (!state.hasAny) return widget.child;

    return Stack(
      children: [
        widget.child,
        if (state.isMinimized)
          const Positioned(right: 16, bottom: 96, child: _MinimizedChip()),
        Positioned(
          left: 8,
          right: 8,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnim,
            child: IgnorePointer(
              ignoring: !state.panelVisible || state.isMinimized,
              child: _TransferPanel(
                onDismiss:
                    ref.read(transferManagerProvider.notifier).hidePanel,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Minimized chip ─────────────────────────────────────────────────────────

class _MinimizedChip extends ConsumerWidget {
  const _MinimizedChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transferManagerProvider);
    final notifier = ref.read(transferManagerProvider.notifier);
    final active = state.tasks.where((t) => t.isActive).length;
    final cs = Theme.of(context).colorScheme;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(24),
      color: cs.primaryContainer,
      child: InkWell(
        onTap: notifier.showPanel,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active > 0 ? Icons.sync_rounded : Icons.done_all_rounded,
                size: 17,
                color: cs.onPrimaryContainer,
              ),
              const SizedBox(width: 7),
              Text(
                active > 0
                    ? '$active transfer${active > 1 ? 's' : ''}'
                    : 'Transfers done',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Transfer panel ─────────────────────────────────────────────────────────

class _TransferPanel extends ConsumerStatefulWidget {
  const _TransferPanel({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  ConsumerState<_TransferPanel> createState() => _TransferPanelState();
}

class _TransferPanelState extends ConsumerState<_TransferPanel> {
  double _dy = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferManagerProvider);
    final notifier = ref.read(transferManagerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final active = state.tasks.where((t) => t.isActive).length;

    return Transform.translate(
      offset: Offset(0, _dy),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: cs.surfaceContainerHigh,
            clipBehavior: Clip.hardEdge,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag-to-dismiss handle ──────────────────────────
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (d) {
                    if (d.delta.dy > 0 || _dy > 0) {
                      setState(() =>
                          _dy = (_dy + d.delta.dy).clamp(0.0, 400.0));
                    }
                  },
                  onVerticalDragEnd: (d) {
                    if (_dy > 80 ||
                        d.velocity.pixelsPerSecond.dy > 400) {
                      setState(() => _dy = 0);
                      widget.onDismiss();
                    } else {
                      setState(() => _dy = 0);
                    }
                  },
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        height: 4,
                        width: 44,
                        decoration: BoxDecoration(
                          color: cs.outline.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 6, 6),
                        child: Row(
                          children: [
                            Icon(Icons.swap_vert_rounded,
                                size: 18, color: cs.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                active > 0
                                    ? 'Transfers ($active active)'
                                    : 'Transfers',
                                style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_rounded,
                                  size: 18),
                              tooltip: 'Minimize',
                              onPressed: () =>
                                  notifier.setMinimized(true),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  size: 18),
                              tooltip: 'Dismiss panel',
                              onPressed: widget.onDismiss,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: state.tasks.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (_, i) =>
                        _TransferRow(task: state.tasks[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Transfer row ───────────────────────────────────────────────────────────

class _TransferRow extends ConsumerWidget {
  const _TransferRow({required this.task});
  final TransferTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(transferManagerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isDone = task.status == TransferStatus.completed;
    final isError = task.status == TransferStatus.error;

    final iconData = switch (task.type) {
      TransferType.upload => Icons.upload_outlined,
      TransferType.download => Icons.download_outlined,
      TransferType.delete => Icons.delete_outline,
      TransferType.copy => Icons.copy_outlined,
      TransferType.move => Icons.drive_file_move_outline,
    };

    final iconColor = isError
        ? cs.error
        : isDone
            ? cs.primary
            : cs.onSurfaceVariant;

    final String statusText;
    if (isError) {
      statusText = task.error ?? 'Failed';
    } else if (isDone) {
      final totalStr =
          task.total > 0 ? FileSizeFormatter.format(task.total) : null;
      statusText = 'Done${totalStr != null ? ' · $totalStr' : ''}';
    } else {
      statusText = switch (task.type) {
        TransferType.delete => 'Deleting…',
        TransferType.copy => 'Copying…',
        TransferType.move => 'Moving…',
        _ => () {
            final xferred = FileSizeFormatter.format(task.transferred);
            final total = task.total > 0
                ? FileSizeFormatter.format(task.total)
                : null;
            final rate = task.bytesPerSec >= 1024
                ? '${FileSizeFormatter.format(task.bytesPerSec.round())}/s'
                : null;
            if (total != null) {
              return '$xferred / $total${rate != null ? ' · $rate' : ''}';
            }
            return xferred + (rate != null ? ' · $rate' : '');
          }(),
      };
    }

    // Download/upload show a determinate bar; delete/copy/move show indeterminate
    final bool showIndeterminate = !isDone &&
        !isError &&
        (task.type == TransferType.delete ||
            task.type == TransferType.copy ||
            task.type == TransferType.move);
    final double? progressValue = (!isDone && !isError && task.total > 0 &&
            (task.type == TransferType.upload ||
                task.type == TransferType.download))
        ? task.progress.clamp(0.0, 1.0)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconData, size: 15, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.name,
                  style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                tooltip: (isDone || isError) ? 'Dismiss' : 'Cancel',
                onPressed: (isDone || isError)
                    ? () => notifier.dismiss(task.id)
                    : () => notifier.cancel(task.id),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 5),
          if (progressValue != null || showIndeterminate) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 3,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            statusText,
            style: tt.bodySmall?.copyWith(
              color: isError ? cs.error : cs.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
