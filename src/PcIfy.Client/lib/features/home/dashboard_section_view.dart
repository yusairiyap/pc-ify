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

    void onReorder(List<DashboardItem> newItems) {
      final layout = ref.read(dashboardLayoutProvider);
      final newSections = layout.sections
          .map((s) => s.id == section.id ? s.copyWith(items: newItems) : s)
          .toList();
      ref
          .read(dashboardLayoutProvider.notifier)
          .update(layout.copyWith(sections: newSections));
    }

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
          _WidgetGrid(
              items: section.items, hasBg: hasBg, onReorder: onReorder),
      ],
    );
  }
}

// ── Draggable widget grid ─────────────────────────────────────────────────────

class _WidgetGrid extends StatefulWidget {
  const _WidgetGrid(
      {required this.items,
      required this.hasBg,
      required this.onReorder});
  final List<DashboardItem> items;
  final bool hasBg;
  final ValueChanged<List<DashboardItem>> onReorder;

  @override
  State<_WidgetGrid> createState() => _WidgetGridState();
}

class _WidgetGridState extends State<_WidgetGrid> {
  late List<DashboardItem> _items;
  int? _draggingIndex;
  int? _hoverIndex;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  @override
  void didUpdateWidget(_WidgetGrid old) {
    super.didUpdateWidget(old);
    if (_draggingIndex == null) _items = List.from(widget.items);
  }

  void _moveItem(int from, int to) {
    if (from == to) return;
    setState(() {
      final item = _items.removeAt(from);
      _items.insert(to, item);
      _draggingIndex = to;
      _hoverIndex = to;
    });
  }

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

    return DragTarget<int>(
      key: ValueKey(item.id),
      onWillAcceptWithDetails: (d) {
        setState(() => _hoverIndex = idx);
        return d.data != idx;
      },
      onLeave: (_) => setState(() => _hoverIndex = null),
      onAcceptWithDetails: (d) {
        _moveItem(d.data, idx);
        setState(() {
          _draggingIndex = null;
          _hoverIndex = null;
        });
        widget.onReorder(List.from(_items));
      },
      builder: (ctx, _, __) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: isHovered
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.primary, width: 2),
              )
            : null,
        child: LongPressDraggable<int>(
          data: idx,
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
          child: _buildCard(item),
        ),
      ),
    );
  }

  Widget _buildCard(DashboardItem item) => switch (item.type) {
        WidgetType.battery => BatteryCard(hasBg: widget.hasBg),
        WidgetType.cpu => CpuCard(hasBg: widget.hasBg),
        WidgetType.ram => RamCard(hasBg: widget.hasBg),
        WidgetType.volume => VolumeCard(hasBg: widget.hasBg),
        WidgetType.screenLock => ScreenLockCard(hasBg: widget.hasBg),
        WidgetType.notifications => NotificationsCard(hasBg: widget.hasBg),
      };
}
