import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/dashboard_models.dart';
import '../../providers/dashboard_providers.dart';
import 'widget_cards/battery_card.dart';
import 'widget_cards/bookmark_section_body.dart';
import 'widget_cards/cpu_card.dart';
import 'widget_cards/notifications_card.dart';
import 'widget_cards/ram_card.dart';
import 'widget_cards/screen_lock_card.dart';
import 'widget_cards/volume_card.dart';

class DashboardSectionView extends ConsumerWidget {
  const DashboardSectionView(
      {super.key, required this.section, required this.hasBg});
  final DashboardSection section;
  final bool hasBg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            section.name,
            style: tt.labelMedium?.copyWith(
              color: hasBg ? Colors.white70 : cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (section.isBookmarks)
          BookmarkSectionBody(hasBg: hasBg)
        else
          _WidgetGrid(section: section, hasBg: hasBg),
      ],
    );
  }
}

// ── Drag payload ──────────────────────────────────────────────────────────────

class _DragData {
  const _DragData(
      {required this.sectionId,
      required this.item,
      required this.fromIndex});
  final String sectionId;
  final DashboardItem item;
  final int fromIndex;
}

// ── Draggable widget grid ─────────────────────────────────────────────────────

class _WidgetGrid extends ConsumerStatefulWidget {
  const _WidgetGrid({required this.section, required this.hasBg});
  final DashboardSection section;
  final bool hasBg;

  @override
  ConsumerState<_WidgetGrid> createState() => _WidgetGridState();
}

class _WidgetGridState extends ConsumerState<_WidgetGrid> {
  late List<DashboardItem> _items;
  int? _draggingIndex;
  int? _hoverIndex;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.section.items);
  }

  @override
  void didUpdateWidget(_WidgetGrid old) {
    super.didUpdateWidget(old);
    if (_draggingIndex == null) _items = List.from(widget.section.items);
  }

  // ── Same-section reorder ──────────────────────────────────────────────────

  void _moveSameSection(int from, int to) {
    if (from == to) return;
    setState(() {
      final item = _items.removeAt(from);
      _items.insert(to, item);
      _draggingIndex = to;
      _hoverIndex = to;
    });
    _commitReorder();
  }

  void _commitReorder() {
    final layout = ref.read(dashboardLayoutProvider);
    final newSections = layout.sections.map((s) {
      if (s.id != widget.section.id) return s;
      return s.copyWith(items: List.from(_items));
    }).toList();
    ref
        .read(dashboardLayoutProvider.notifier)
        .update(layout.copyWith(sections: newSections));
  }

  // ── Cross-section drop ────────────────────────────────────────────────────

  void _moveCrossSection(_DragData data, int targetIdx) {
    final layout = ref.read(dashboardLayoutProvider);

    final srcSec = layout.sections
        .where((s) => s.id == data.sectionId)
        .firstOrNull;
    if (srcSec == null) return;
    final realSrcIdx =
        srcSec.items.indexWhere((i) => i.id == data.item.id);
    if (realSrcIdx == -1) return;

    final newSrcItems = List<DashboardItem>.from(srcSec.items)
      ..removeAt(realSrcIdx);

    final newDstItems = List<DashboardItem>.from(_items);
    newDstItems.insert(targetIdx.clamp(0, newDstItems.length), data.item);

    final newSections = layout.sections.map((s) {
      if (s.id == data.sectionId) return s.copyWith(items: newSrcItems);
      if (s.id == widget.section.id) return s.copyWith(items: newDstItems);
      return s;
    }).toList();

    ref
        .read(dashboardLayoutProvider.notifier)
        .update(layout.copyWith(sections: newSections));

    setState(() {
      _items = newDstItems;
      _draggingIndex = null;
      _hoverIndex = null;
    });
  }

  // ── Resize ────────────────────────────────────────────────────────────────

  void _resizeItem(DashboardItem item, WidgetSize size) {
    final layout = ref.read(dashboardLayoutProvider);
    final newSections = layout.sections.map((s) {
      if (s.id != widget.section.id) return s;
      return s.copyWith(
        items: s.items
            .map((i) => i.id == item.id ? i.copyWith(size: size) : i)
            .toList(),
      );
    }).toList();
    ref
        .read(dashboardLayoutProvider.notifier)
        .update(layout.copyWith(sections: newSections));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    final pending = <(int, DashboardItem)>[];

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.effectiveSize == WidgetSize.halfWidth) {
        pending.add((i, item));
        if (pending.length == 2) {
          rows.add(_halfRow(pending[0], pending[1]));
          pending.clear();
        }
      } else {
        if (pending.isNotEmpty) {
          rows.add(_halfRow(pending[0], null));
          pending.clear();
        }
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: _draggableCard(i, item),
        ));
      }
    }
    if (pending.isNotEmpty) rows.add(_halfRow(pending[0], null));

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  Widget _halfRow((int, DashboardItem) a, (int, DashboardItem)? b) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _draggableCard(a.$1, a.$2)),
              if (b != null) ...[
                const SizedBox(width: 8),
                Expanded(child: _draggableCard(b.$1, b.$2)),
              ] else
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      );

  Widget _draggableCard(int idx, DashboardItem item) {
    final isHovered = _hoverIndex == idx && _draggingIndex != idx;
    final cs = Theme.of(context).colorScheme;

    return DragTarget<_DragData>(
      key: ValueKey(item.id),
      onWillAcceptWithDetails: (d) {
        setState(() => _hoverIndex = idx);
        return d.data.item.id != item.id;
      },
      onLeave: (_) => setState(() => _hoverIndex = null),
      onAcceptWithDetails: (d) {
        if (d.data.sectionId == widget.section.id) {
          _moveSameSection(d.data.fromIndex, idx);
        } else {
          _moveCrossSection(d.data, idx);
        }
        setState(() {
          _draggingIndex = null;
          _hoverIndex = null;
        });
      },
      builder: (ctx, _, __) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: isHovered
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.primary, width: 2),
              )
            : null,
        child: LongPressDraggable<_DragData>(
          data: _DragData(
              sectionId: widget.section.id, item: item, fromIndex: idx),
          delay: const Duration(milliseconds: 400),
          onDragStarted: () => setState(() => _draggingIndex = idx),
          onDragEnd: (_) => setState(() {
            _draggingIndex = null;
            _hoverIndex = null;
          }),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.85,
              child: SizedBox(
                width: 160,
                height: 90,
                child: _buildCard(item),
              ),
            ),
          ),
          childWhenDragging:
              Opacity(opacity: 0.3, child: _buildCard(item)),
          child: _withResizeHandle(item),
        ),
      ),
    );
  }

  Widget _withResizeHandle(DashboardItem item) => Stack(
        children: [
          _buildCard(item),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 20,
            child: _ResizeHandle(
              item: item,
              onResize: (size) => _resizeItem(item, size),
            ),
          ),
        ],
      );

  Widget _buildCard(DashboardItem item) => switch (item.type) {
        WidgetType.battery => BatteryCard(hasBg: widget.hasBg),
        WidgetType.cpu => CpuCard(hasBg: widget.hasBg),
        WidgetType.ram => RamCard(hasBg: widget.hasBg),
        WidgetType.volume => VolumeCard(hasBg: widget.hasBg),
        WidgetType.screenLock => ScreenLockCard(hasBg: widget.hasBg),
        WidgetType.notifications => NotificationsCard(hasBg: widget.hasBg),
      };
}

// ── Resize handle ─────────────────────────────────────────────────────────────

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.item, required this.onResize});
  final DashboardItem item;
  final void Function(WidgetSize) onResize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final vx = details.velocity.pixelsPerSecond.dx;
        if (vx > 100 && item.effectiveSize == WidgetSize.halfWidth) {
          onResize(WidgetSize.fullWidth);
        } else if (vx < -100 && item.effectiveSize == WidgetSize.fullWidth) {
          onResize(WidgetSize.halfWidth);
        }
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(cs),
            const SizedBox(height: 3),
            _dot(cs),
            const SizedBox(height: 3),
            _dot(cs),
          ],
        ),
      ),
    );
  }

  Widget _dot(ColorScheme cs) => Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
      );
}
