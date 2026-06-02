import 'package:flutter/material.dart';
import '../../core/models/dashboard_models.dart';

class DashboardSectionEditor extends StatelessWidget {
  const DashboardSectionEditor({
    super.key,
    required this.section,
    required this.hasBg,
    required this.onDelete,
    required this.onRename,
    required this.onAddWidget,
    required this.onRemoveWidget,
    required this.onResizeWidget,
    required this.onReorderWidgets,
  });

  final DashboardSection section;
  final bool hasBg;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback onAddWidget;
  final ValueChanged<String> onRemoveWidget;
  final void Function(String itemId, WidgetSize size) onResizeWidget;
  final ValueChanged<List<DashboardItem>> onReorderWidgets;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.drag_handle, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onRename,
                  child: Text(
                    section.name,
                    style:
                        tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Tooltip(
                message: 'Rename',
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: onRename,
                ),
              ),
              Tooltip(
                message: section.isBookmarks
                    ? 'Remove bookmarks section'
                    : 'Delete section',
                child: IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: cs.error),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: onDelete,
                ),
              ),
            ]),
            const Divider(height: 12),
            if (section.isBookmarks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Bookmark folders (manage from Browse tab)',
                  style:
                      TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              )
            else ...[
              if (section.items.isNotEmpty)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: section.items.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final newItems =
                        List<DashboardItem>.from(section.items);
                    final item = newItems.removeAt(oldIndex);
                    newItems.insert(newIndex, item);
                    onReorderWidgets(newItems);
                  },
                  itemBuilder: (context, index) {
                    final item = section.items[index];
                    final isHalf =
                        item.effectiveSize == WidgetSize.halfWidth;
                    return ListTile(
                      key: ValueKey(item.id),
                      dense: true,
                      leading: Icon(_widgetIcon(item.type),
                          size: 18, color: cs.primary),
                      title: Text(_widgetName(item.type),
                          style: const TextStyle(fontSize: 13)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: isHalf
                                ? 'Expand to full width'
                                : 'Shrink to half width',
                            child: IconButton(
                              icon: Icon(
                                isHalf
                                    ? Icons.open_in_full
                                    : Icons.close_fullscreen,
                                size: 16,
                                color: cs.onSurfaceVariant,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              onPressed: () => onResizeWidget(
                                item.id,
                                isHalf
                                    ? WidgetSize.fullWidth
                                    : WidgetSize.halfWidth,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline,
                                size: 18, color: cs.error),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            onPressed: () => onRemoveWidget(item.id),
                          ),
                          const Icon(Icons.drag_handle,
                              size: 18, color: Colors.grey),
                        ],
                      ),
                    );
                  },
                ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add widget',
                    style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onAddWidget,
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _widgetIcon(WidgetType type) => switch (type) {
        WidgetType.battery => Icons.battery_full_outlined,
        WidgetType.volume => Icons.volume_up_outlined,
        WidgetType.cpu => Icons.memory_outlined,
        WidgetType.ram => Icons.storage_outlined,
        WidgetType.screenLock => Icons.lock_outline,
      };

  String _widgetName(WidgetType type) => switch (type) {
        WidgetType.battery => 'Battery',
        WidgetType.volume => 'Volume',
        WidgetType.cpu => 'CPU Usage',
        WidgetType.ram => 'RAM Usage',
        WidgetType.screenLock => 'Screen Lock',
      };
}
