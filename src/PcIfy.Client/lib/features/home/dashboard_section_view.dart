import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/dashboard_models.dart';
import '../../providers/dashboard_providers.dart';
import 'widget_cards/battery_card.dart';
import 'widget_cards/bookmark_section_body.dart';
import 'widget_cards/cpu_card.dart';
import 'widget_cards/ram_card.dart';
import 'widget_cards/screen_lock_card.dart';
import 'widget_cards/server_info_card.dart';
import 'widget_cards/volume_card.dart';

const _kResizeThreshold = 40.0;
const _kTallMinHeight = 180.0;

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
      if (!item.effectiveSize.isWide) {
        // halfWidth or halfWidthTall — pair up two per row
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final feedbackWidth = item.effectiveSize.isWide
        ? screenWidth - 32
        : (screenWidth - 40) / 2;

    // Displacement: hovered widget slides aside to signal "I'll move here"
    final slideOffset = isHovered
        ? (item.effectiveSize.isWide
            ? const Offset(0, 0.04)
            : const Offset(0.07, 0))
        : Offset.zero;

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
      builder: (ctx, _, __) => AnimatedSlide(
        offset: slideOffset,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: isHovered
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: cs.primary.withValues(alpha: 0.6), width: 2),
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
                child: SizedBox(width: feedbackWidth, child: _buildCard(item)),
              ),
            ),
            childWhenDragging:
                Opacity(opacity: 0.3, child: _buildCard(item)),
            child: _withResizeHandle(item),
          ),
        ),
      ),
    );
  }

  // Wraps card with corner resize handle and animates size changes.
  Widget _withResizeHandle(DashboardItem item) {
    final targetH = item.effectiveSize.isTall ? _kTallMinHeight : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: targetH),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      builder: (_, h, child) => h > 0
          ? ConstrainedBox(
              constraints: BoxConstraints(minHeight: h),
              child: child,
            )
          : child!,
      child: Stack(
        children: [
          _buildCard(item),
          Positioned(
            right: 4,
            bottom: 4,
            child: _CornerResizeHandle(
              item: item,
              onResize: (size) => _resizeItem(item, size),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(DashboardItem item) => switch (item.type) {
        WidgetType.battery => BatteryCard(hasBg: widget.hasBg),
        WidgetType.cpu => CpuCard(hasBg: widget.hasBg),
        WidgetType.ram => RamCard(hasBg: widget.hasBg),
        WidgetType.volume => VolumeCard(hasBg: widget.hasBg),
        WidgetType.screenLock => ScreenLockCard(hasBg: widget.hasBg),
        WidgetType.serverInfo => ServerInfoCard(hasBg: widget.hasBg),
      };
}

// ── Corner resize handle (H + V) ─────────────────────────────────────────────

class _CornerResizeHandle extends StatefulWidget {
  const _CornerResizeHandle({required this.item, required this.onResize});
  final DashboardItem item;
  final void Function(WidgetSize) onResize;

  @override
  State<_CornerResizeHandle> createState() => _CornerResizeHandleState();
}

class _CornerResizeHandleState extends State<_CornerResizeHandle>
    with SingleTickerProviderStateMixin {
  double _totalDx = 0;
  double _totalDy = 0;
  bool _active = false;

  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails _) {
    setState(() {
      _active = true;
      _totalDx = 0;
      _totalDy = 0;
    });
    _ctrl.repeat(reverse: true);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _totalDx += d.delta.dx;
      _totalDy += d.delta.dy;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    _ctrl.stop();
    _ctrl.reset();
    final dx = _totalDx;
    final dy = _totalDy;
    final vel = d.velocity.pixelsPerSecond;
    setState(() {
      _active = false;
      _totalDx = 0;
      _totalDy = 0;
    });
    final newSize = _computeNewSize(widget.item.effectiveSize, dx, dy, vel);
    if (newSize != widget.item.effectiveSize) {
      widget.onResize(newSize);
    }
  }

  void _onPanCancel() {
    _ctrl.stop();
    _ctrl.reset();
    setState(() {
      _active = false;
      _totalDx = 0;
      _totalDy = 0;
    });
  }

  WidgetSize _computeNewSize(
      WidgetSize current, double dx, double dy, Offset velocity) {
    bool isWide = current.isWide;
    bool isTall = current.isTall;

    if (dx > _kResizeThreshold || velocity.dx > 300) isWide = true;
    if (dx < -_kResizeThreshold || velocity.dx < -300) isWide = false;
    if (dy > _kResizeThreshold || velocity.dy > 300) isTall = true;
    if (dy < -_kResizeThreshold || velocity.dy < -300) isTall = false;

    return switch ((isWide, isTall)) {
      (false, false) => WidgetSize.halfWidth,
      (true, false) => WidgetSize.fullWidth,
      (false, true) => WidgetSize.halfWidthTall,
      _ => WidgetSize.fullWidthTall,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _active
        ? cs.primary.withValues(alpha: 0.9)
        : cs.onSurfaceVariant.withValues(alpha: 0.45);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _active ? _scale.value : 1.0,
          alignment: Alignment.bottomRight,
          child: child,
        ),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CustomPaint(painter: _CornerGripPainter(color: color)),
        ),
      ),
    );
  }
}

// Draws a resize-grip: three short diagonal lines at the bottom-right corner.
class _CornerGripPainter extends CustomPainter {
  const _CornerGripPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const gap = 4.0;
    const len = 6.0;
    for (var i = 0; i < 3; i++) {
      final offset = i * gap;
      canvas.drawLine(
        Offset(size.width - offset, size.height - len),
        Offset(size.width - len, size.height - offset),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CornerGripPainter old) => old.color != color;
}
