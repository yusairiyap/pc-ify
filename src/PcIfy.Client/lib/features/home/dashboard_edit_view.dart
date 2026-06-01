import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/dashboard_models.dart';
import '../../providers/dashboard_providers.dart';
import 'add_section_dialog.dart';
import 'add_widget_bottom_sheet.dart';
import 'dashboard_section_editor.dart';

class DashboardEditView extends ConsumerWidget {
  const DashboardEditView(
      {super.key, required this.layout, required this.hasBg});
  final DashboardLayout layout;
  final bool hasBg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = layout.sections;

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
            itemCount: sections.length,
            onReorderItem: (oldIndex, newIndex) {
              final newSections = List<DashboardSection>.from(sections);
              final item = newSections.removeAt(oldIndex);
              newSections.insert(newIndex, item);
              ref
                  .read(dashboardLayoutProvider.notifier)
                  .update(layout.copyWith(sections: newSections));
            },
            itemBuilder: (context, index) {
              final section = sections[index];
              return DashboardSectionEditor(
                key: ValueKey(section.id),
                section: section,
                hasBg: hasBg,
                onDelete: () => _deleteSection(context, ref, section),
                onRename: () => _renameSection(context, ref, section),
                onAddWidget: () => _addWidget(context, ref, section),
                onRemoveWidget: (itemId) =>
                    _removeWidget(ref, section, itemId),
                onReorderWidgets: (newItems) =>
                    _reorderWidgets(ref, section, newItems),
              );
            },
          ),
        ),
        // Add section footer
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add section'),
            style: OutlinedButton.styleFrom(
              foregroundColor: hasBg ? Colors.white70 : null,
              side: hasBg ? const BorderSide(color: Colors.white30) : null,
            ),
            onPressed: () => _addSection(context, ref),
          ),
        ),
      ],
    );
  }

  void _deleteSection(
      BuildContext context, WidgetRef ref, DashboardSection section) {
    final newSections =
        layout.sections.where((s) => s.id != section.id).toList();
    ref
        .read(dashboardLayoutProvider.notifier)
        .update(layout.copyWith(sections: newSections));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${section.name}" removed'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => ref
            .read(dashboardLayoutProvider.notifier)
            .update(layout), // restore original
      ),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _renameSection(
      BuildContext context, WidgetRef ref, DashboardSection section) async {
    if (section.isBookmarks) return; // can't rename bookmarks section
    final controller = TextEditingController(text: section.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename section'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Section name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    final updated = section.copyWith(name: newName);
    final newSections = layout.sections
        .map((s) => s.id == section.id ? updated : s)
        .toList();
    ref
        .read(dashboardLayoutProvider.notifier)
        .update(layout.copyWith(sections: newSections));
  }

  Future<void> _addWidget(
      BuildContext context, WidgetRef ref, DashboardSection section) async {
    final allUsed = layout.sections
        .expand((s) => s.items.map((i) => i.type))
        .toSet();
    final picked =
        await showAddWidgetSheet(context, alreadyAdded: allUsed.toList());
    if (picked == null) return;
    final newItem = DashboardItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: picked,
    );
    final updated = section.copyWith(items: [...section.items, newItem]);
    final newSections = layout.sections
        .map((s) => s.id == section.id ? updated : s)
        .toList();
    ref
        .read(dashboardLayoutProvider.notifier)
        .update(layout.copyWith(sections: newSections));
  }

  void _removeWidget(WidgetRef ref, DashboardSection section, String itemId) {
    final updated = section.copyWith(
        items: section.items.where((i) => i.id != itemId).toList());
    final newSections = layout.sections
        .map((s) => s.id == section.id ? updated : s)
        .toList();
    ref
        .read(dashboardLayoutProvider.notifier)
        .update(layout.copyWith(sections: newSections));
  }

  void _reorderWidgets(
      WidgetRef ref, DashboardSection section, List<DashboardItem> newItems) {
    final updated = section.copyWith(items: newItems);
    final newSections = layout.sections
        .map((s) => s.id == section.id ? updated : s)
        .toList();
    ref
        .read(dashboardLayoutProvider.notifier)
        .update(layout.copyWith(sections: newSections));
  }

  Future<void> _addSection(BuildContext context, WidgetRef ref) async {
    final hasBookmarks = layout.sections.any((s) => s.isBookmarks);
    final newSection = await showAddSectionDialog(context,
        bookmarksAlreadyPresent: hasBookmarks);
    if (newSection == null) return;
    ref.read(dashboardLayoutProvider.notifier).update(
        layout.copyWith(sections: [...layout.sections, newSection]));
  }
}
