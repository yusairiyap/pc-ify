import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/transfer_task.dart';
import '../core/utils/file_size_formatter.dart';
import '../providers/transfer_providers.dart';

class TransferOverlay extends ConsumerWidget {
  const TransferOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transferManagerProvider);
    if (!state.panelVisible || !state.hasAny) return child;

    return Stack(
      children: [
        child,
        if (state.isMinimized)
          Positioned(
            right: 16,
            bottom: 96,
            child: _MinimizedChip(),
          )
        else
          Positioned(
            left: 8,
            right: 8,
            bottom: 0,
            child: _TransferPanel(),
          ),
      ],
    );
  }
}

class _MinimizedChip extends ConsumerWidget {
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

class _TransferPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transferManagerProvider);
    final notifier = ref.read(transferManagerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final active = state.tasks.where((t) => t.isActive).length;

    return SafeArea(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 6, 6),
                child: Row(
                  children: [
                    Icon(Icons.swap_vert_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        active > 0
                            ? 'Transfers ($active active)'
                            : 'Transfers',
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      tooltip: 'Minimize',
                      onPressed: () => notifier.setMinimized(true),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Dismiss panel',
                      onPressed: notifier.hidePanel,
                      visualDensity: VisualDensity.compact,
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
    );
  }
}

class _TransferRow extends ConsumerWidget {
  const _TransferRow({required this.task});
  final TransferTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(transferManagerProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isUpload = task.type == TransferType.upload;
    final isDone = task.status == TransferStatus.completed;
    final isError = task.status == TransferStatus.error;

    final iconColor = isError
        ? cs.error
        : isDone
            ? cs.primary
            : cs.onSurfaceVariant;

    final transferredStr = FileSizeFormatter.format(task.transferred);
    final totalStr =
        task.total > 0 ? FileSizeFormatter.format(task.total) : null;
    final rateStr = task.bytesPerSec >= 1024
        ? '${FileSizeFormatter.format(task.bytesPerSec.round())}/s'
        : null;

    final String statusText;
    if (isError) {
      statusText = task.error ?? 'Failed';
    } else if (isDone) {
      statusText = 'Done${totalStr != null ? ' · $totalStr' : ''}';
    } else if (totalStr != null) {
      statusText =
          '$transferredStr / $totalStr${rateStr != null ? ' · $rateStr' : ''}';
    } else {
      statusText =
          transferredStr + (rateStr != null ? ' · $rateStr' : '');
    }

    final progressValue = (!isDone && !isError && task.total > 0)
        ? task.progress.clamp(0.0, 1.0)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUpload ? Icons.upload_outlined : Icons.download_outlined,
                size: 15,
                color: iconColor,
              ),
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
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 5),
          if (!isDone && !isError)
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 3,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
          if (!isDone && !isError) const SizedBox(height: 4),
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
