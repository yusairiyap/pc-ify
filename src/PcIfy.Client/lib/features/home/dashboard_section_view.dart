import 'package:flutter/material.dart';
import '../../core/models/dashboard_models.dart';
import 'widget_cards/battery_card.dart';
import 'widget_cards/bookmark_section_body.dart';
import 'widget_cards/cpu_card.dart';
import 'widget_cards/notifications_card.dart';
import 'widget_cards/ram_card.dart';
import 'widget_cards/screen_lock_card.dart';
import 'widget_cards/volume_card.dart';

class DashboardSectionView extends StatelessWidget {
  const DashboardSectionView(
      {super.key, required this.section, required this.hasBg});
  final DashboardSection section;
  final bool hasBg;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
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
        // Section content
        if (section.isBookmarks)
          BookmarkSectionBody(hasBg: hasBg)
        else
          _WidgetGrid(items: section.items, hasBg: hasBg),
      ],
    );
  }
}

class _WidgetGrid extends StatelessWidget {
  const _WidgetGrid({required this.items, required this.hasBg});
  final List<DashboardItem> items;
  final bool hasBg;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    final halfItems = <DashboardItem>[];

    for (final item in items) {
      if (_isHalfWidth(item.type)) {
        halfItems.add(item);
        if (halfItems.length == 2) {
          rows.add(_halfRow(halfItems[0], halfItems[1]));
          halfItems.clear();
        }
      } else {
        if (halfItems.isNotEmpty) {
          // Lone half-width item before a full-width one
          rows.add(_halfRow(halfItems[0], null));
          halfItems.clear();
        }
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: _buildCard(item),
        ));
      }
    }
    // Remaining single half-width item
    if (halfItems.isNotEmpty) {
      rows.add(_halfRow(halfItems[0], null));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  bool _isHalfWidth(WidgetType t) =>
      t == WidgetType.battery || t == WidgetType.cpu || t == WidgetType.ram;

  Widget _halfRow(DashboardItem a, DashboardItem? b) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildCard(a)),
              if (b != null) ...[
                const SizedBox(width: 8),
                Expanded(child: _buildCard(b)),
              ] else
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      );

  Widget _buildCard(DashboardItem item) => switch (item.type) {
        WidgetType.battery => BatteryCard(hasBg: hasBg),
        WidgetType.cpu => CpuCard(hasBg: hasBg),
        WidgetType.ram => RamCard(hasBg: hasBg),
        WidgetType.volume => VolumeCard(hasBg: hasBg),
        WidgetType.screenLock => ScreenLockCard(hasBg: hasBg),
        WidgetType.notifications => NotificationsCard(hasBg: hasBg),
      };
}
