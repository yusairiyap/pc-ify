import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/dashboard_models.dart';
import '../../providers/dashboard_providers.dart';
import 'add_section_dialog.dart';
import 'add_widget_bottom_sheet.dart';
import 'dashboard_section_editor.dart';

class DashboardEditView extends ConsumerStatefulWidget {
  const DashboardEditView(
      {super.key, required this.layout, required this.hasBg});
  final DashboardLayout layout;
  final bool hasBg;

  @override
  ConsumerState<DashboardEditView> createState() => _DashboardEditViewState();
}

class _DashboardEditViewState extends ConsumerState<DashboardEditView> {
  DashboardLayout get _layout => ref.read(dashboardLayoutProvider);

  void _save(DashboardLayout newLayout) {
    ref.read(dashboardLayoutProvider.notifier).update(newLayout);
  }

  void _deleteSection(DashboardSection section) {
    final current = _layout;
    final newSections =
        current.sections.where((s) => s.id != section.id).toList();
    _save(current.copyWith(sections: newSections));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${section.name}" removed'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => _save(current),
      ),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _renameSection(DashboardSection section) async {
    final controller = TextEditingController(text: section.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename section'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Section name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (newName == null || newName.isEmpty) return;
    final current = _layout;
    final newSections = current.sections
        .map((s) => s.id == section.id ? s.copyWith(name: newName) : s)
        .toList();
    _save(current.copyWith(sections: newSections));
  }

  Future<void> _addWidget(DashboardSection section) async {
    final current = _layout;
    final allUsed =
        current.sections.expand((s) => s.items.map((i) => i.type)).toSet();
    final picked =
        await showAddWidgetSheet(context, alreadyAdded: allUsed.toList());
    if (!mounted || picked == null) return;
    final newItem = DashboardItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: picked,
    );
    final fresh = _layout;
    final newSections = fresh.sections.map((s) {
      if (s.id != section.id) return s;
      return s.copyWith(items: [...s.items, newItem]);
    }).toList();
    _save(fresh.copyWith(sections: newSections));
  }

  void _removeWidget(DashboardSection section, String itemId) {
    final current = _layout;
    final newSections = current.sections.map((s) {
      if (s.id != section.id) return s;
      return s.copyWith(items: s.items.where((i) => i.id != itemId).toList());
    }).toList();
    _save(current.copyWith(sections: newSections));
  }

  void _resizeWidget(
      DashboardSection section, String itemId, WidgetSize size) {
    final current = _layout;
    final newSections = current.sections.map((s) {
      if (s.id != section.id) return s;
      return s.copyWith(
          items: s.items
              .map((i) => i.id == itemId ? i.copyWith(size: size) : i)
              .toList());
    }).toList();
    _save(current.copyWith(sections: newSections));
  }

  void _reorderWidgets(
      DashboardSection section, List<DashboardItem> newItems) {
    final current = _layout;
    final newSections = current.sections.map((s) {
      if (s.id != section.id) return s;
      return s.copyWith(items: newItems);
    }).toList();
    _save(current.copyWith(sections: newSections));
  }

  Future<void> _addSection() async {
    final hasBookmarks = _layout.sections.any((s) => s.isBookmarks);
    final newSection = await showAddSectionDialog(context,
        bookmarksAlreadyPresent: hasBookmarks);
    if (!mounted || newSection == null) return;
    final fresh = _layout;
    _save(fresh.copyWith(sections: [...fresh.sections, newSection]));
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.layout.sections;

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
            itemCount: sections.length,
            onReorderItem: (oldIndex, newIndex) {
              final current = _layout;
              final newSections =
                  List<DashboardSection>.from(current.sections);
              final item = newSections.removeAt(oldIndex);
              newSections.insert(newIndex, item);
              _save(current.copyWith(sections: newSections));
            },
            itemBuilder: (context, index) {
              final section = sections[index];
              return DashboardSectionEditor(
                key: ValueKey(section.id),
                section: section,
                hasBg: widget.hasBg,
                onDelete: () => _deleteSection(section),
                onRename: () => _renameSection(section),
                onAddWidget: () => _addWidget(section),
                onRemoveWidget: (itemId) => _removeWidget(section, itemId),
                onResizeWidget: (itemId, size) =>
                    _resizeWidget(section, itemId, size),
                onReorderWidgets: (newItems) =>
                    _reorderWidgets(section, newItems),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add section'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.hasBg ? Colors.white70 : null,
              side: widget.hasBg
                  ? const BorderSide(color: Colors.white30)
                  : null,
            ),
            onPressed: _addSection,
          ),
        ),
      ],
    );
  }
}
