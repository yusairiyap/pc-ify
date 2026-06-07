import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/dashboard_models.dart';
import '../../providers/dashboard_providers.dart';
import 'widget_cards/battery_card.dart';
import 'widget_cards/bookmark_section_body.dart';
import 'widget_cards/cpu_card.dart';
import 'widget_cards/disk_card.dart';
import 'widget_cards/ram_card.dart';
import 'widget_cards/screen_lock_card.dart';
import 'widget_cards/server_info_card.dart';
import 'widget_cards/volume_card.dart';

const _kTallMinHeight = 180.0;
const _kNormalMinHeight = 112.0;

class DashboardSectionView extends ConsumerStatefulWidget {
  const DashboardSectionView({
    super.key,
    required this.section,
    required this.hasBg,
    this.editMode = false,
    this.sectionIndex,
    this.onDelete,
    this.onRename,
    this.onAddWidget,
    this.onRemoveWidget,
  });
  final DashboardSection section;
  final bool hasBg;
  final bool editMode;
  final int? sectionIndex;
  final VoidCallback? onDelete;
  final void Function(String newName)? onRename;
  final VoidCallback? onAddWidget;
  final void Function(String itemId)? onRemoveWidget;

  @override
  ConsumerState<DashboardSectionView> createState() => _DashboardSectionViewState();
}

class _DashboardSectionViewState extends ConsumerState<DashboardSectionView> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.section.name);
  }

  @override
  void didUpdateWidget(DashboardSectionView old) {
    super.didUpdateWidget(old);
    if (old.section.name != widget.section.name) {
      _nameCtrl.text = widget.section.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _commitRename() {
    final trimmed = _nameCtrl.text.trim();
    if (trimmed.isNotEmpty && trimmed != widget.section.name) {
      widget.onRename?.call(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final section = widget.section;
    final hasBg = widget.hasBg;

    if (!widget.editMode) {
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
            _WidgetGrid(section: section, hasBg: hasBg, editMode: false),
        ],
      );
    }

    // Edit mode
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header: drag handle + inline rename + delete + add widget
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Row(
            children: [
              if (widget.sectionIndex != null)
                ReorderableDelayedDragStartListener(
                  index: widget.sectionIndex!,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.drag_handle, size: 22, color: Colors.grey),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.drag_handle, size: 22, color: Colors.grey),
                ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    border: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: cs.primary, width: 1.5),
                    ),
                    hintText: 'Section name',
                    hintStyle: TextStyle(color: cs.outline),
                  ),
                  onSubmitted: (_) => _commitRename(),
                  onEditingComplete: _commitRename,
                ),
              ),
              if (!section.isBookmarks)
                Tooltip(
                  message: 'Add widget',
                  child: IconButton(
                    icon: Icon(Icons.add_circle_outline, size: 18, color: cs.primary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: widget.onAddWidget,
                  ),
                ),
              Tooltip(
                message: section.isBookmarks ? 'Remove bookmarks section' : 'Delete section',
                child: IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: widget.onDelete,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 8, indent: 16, endIndent: 16),
        if (section.isBookmarks)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Bookmark folders (manage from Browse tab)',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          )
        else
          _WidgetGrid(
            section: section,
            hasBg: hasBg,
            editMode: true,
            onRemoveItem: widget.onRemoveWidget,
          ),
        const SizedBox(height: 8),
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
  const _WidgetGrid({
    required this.section,
    required this.hasBg,
    required this.editMode,
    this.onRemoveItem,
  });
  final DashboardSection section;
  final bool hasBg;
  final bool editMode;
  final void Function(String itemId)? onRemoveItem;

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
          child: widget.editMode ? _draggableCard(i, item) : _buildCard(item),
        ));
      }
    }
    if (pending.isNotEmpty) rows.add(_halfRow(pending[0], null));

    final layoutKey = _items
        .map((i) => '${i.id}:${i.effectiveSize.name}')
        .join(',');
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Column(
        key: ValueKey(layoutKey),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  Widget _halfRow((int, DashboardItem) a, (int, DashboardItem)? b) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: widget.editMode ? _draggableCard(a.$1, a.$2) : _buildCard(a.$2)),
            const SizedBox(width: 8),
            if (b != null)
              Expanded(child: widget.editMode ? _draggableCard(b.$1, b.$2) : _buildCard(b.$2))
            else if (widget.editMode)
              Expanded(child: _emptySlotTarget(a.$1 + 1))
            else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );

  // ── Empty half-row drop target (edit mode only) ───────────────────────────

  Widget _emptySlotTarget(int insertIdx) {
    return DragTarget<_DragData>(
      onWillAcceptWithDetails: (d) => !d.data.item.effectiveSize.isWide,
      onLeave: (_) => setState(() => _hoverIndex = null),
      onAcceptWithDetails: (d) {
        if (d.data.sectionId == widget.section.id) {
          _moveSameSection(d.data.fromIndex, insertIdx.clamp(0, _items.length));
        } else {
          _moveCrossSection(d.data, insertIdx.clamp(0, _items.length));
        }
        setState(() {
          _draggingIndex = null;
          _hoverIndex = null;
        });
      },
      builder: (ctx, candidates, __) {
        final cs = Theme.of(ctx).colorScheme;
        final isHovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: _kNormalMinHeight,
          decoration: isHovering
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.primary, width: 2),
                  color: cs.primaryContainer.withValues(alpha: 0.2),
                )
              : null,
        );
      },
    );
  }

  // ── Draggable card (edit mode only) ──────────────────────────────────────

  Widget _draggableCard(int idx, DashboardItem item) {
    final isHovered = _hoverIndex == idx && _draggingIndex != idx;
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final feedbackWidth = item.effectiveSize.isWide
        ? screenWidth - 32
        : (screenWidth - 40) / 2;

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
            child: _buildCardWithEditOverlays(item),
          ),
        ),
      ),
    );
  }

  Widget _buildCardWithEditOverlays(DashboardItem item) {
    final badge = _SizeBadge(
      item: item,
      onResize: (size) => _resizeItem(item, size),
    );
    final removeBtn = _RemoveIcon(onTap: () => widget.onRemoveItem?.call(item.id));
    return _buildCard(item, badge: badge, removeIcon: removeBtn);
  }

  // Fixed heights ensure all cards of the same size class are consistent.
  Widget _buildCard(DashboardItem item, {Widget? badge, Widget? removeIcon}) {
    final size = item.effectiveSize;
    Widget card = switch (item.type) {
      WidgetType.battery => BatteryCard(hasBg: widget.hasBg, size: size, badge: badge),
      WidgetType.cpu => CpuCard(hasBg: widget.hasBg, size: size, badge: badge),
      WidgetType.ram => RamCard(hasBg: widget.hasBg, size: size, badge: badge),
      WidgetType.volume => VolumeCard(hasBg: widget.hasBg, size: size, badge: badge),
      WidgetType.screenLock => ScreenLockCard(hasBg: widget.hasBg, size: size, badge: badge),
      WidgetType.serverInfo => ServerInfoCard(hasBg: widget.hasBg, size: size, badge: badge),
      WidgetType.disk => DiskCard(hasBg: widget.hasBg, size: size, badge: badge),
    };
    if (removeIcon != null) {
      card = Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(top: -8, left: -8, child: removeIcon),
        ],
      );
    }
    if (size.isTall) return SizedBox(height: _kTallMinHeight, child: card);
    if (!size.isWide) return SizedBox(height: _kNormalMinHeight, child: card);
    return card;
  }
}

// ── Remove icon overlay ───────────────────────────────────────────────────────

class _RemoveIcon extends StatelessWidget {
  const _RemoveIcon({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: cs.error,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Icon(Icons.close, size: 13, color: cs.onError),
      ),
    );
  }
}

// ── Tap-based size badge ──────────────────────────────────────────────────────

class _SizeBadge extends StatelessWidget {
  const _SizeBadge({required this.item, required this.onResize});
  final DashboardItem item;
  final void Function(WidgetSize) onResize;

  static String _label(WidgetSize s) => switch (s) {
        WidgetSize.halfWidth => '2×1',
        WidgetSize.fullWidth => '4×1',
        WidgetSize.halfWidthTall => '2×2',
        WidgetSize.fullWidthTall => '4×2',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = item.effectiveSize;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _showPicker(context, cs, current),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outline.withValues(alpha: 0.4), width: 0.5),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Text(
          _label(current),
          style: TextStyle(
            fontSize: 10,
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, ColorScheme cs, WidgetSize current) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    showMenu<WidgetSize>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx - 96,
        offset.dy - 152,
        offset.dx + size.width,
        offset.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: WidgetSize.values
          .map(
            (s) => PopupMenuItem<WidgetSize>(
              value: s,
              height: 40,
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      _label(s),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: s == current
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: s == current ? cs.primary : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _description(s),
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ),
                  if (s == current)
                    Icon(Icons.check_rounded, size: 16, color: cs.primary),
                ],
              ),
            ),
          )
          .toList(),
    ).then((chosen) {
      if (chosen != null && chosen != current) onResize(chosen);
    });
  }

  static String _description(WidgetSize s) => switch (s) {
        WidgetSize.halfWidth => 'Half width',
        WidgetSize.fullWidth => 'Full width',
        WidgetSize.halfWidthTall => 'Half width, tall',
        WidgetSize.fullWidthTall => 'Full width, tall',
      };
}
