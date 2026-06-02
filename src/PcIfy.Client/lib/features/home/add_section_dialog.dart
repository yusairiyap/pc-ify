import 'package:flutter/material.dart';
import '../../core/models/dashboard_models.dart';

Future<DashboardSection?> showAddSectionDialog(
  BuildContext context, {
  required bool bookmarksAlreadyPresent,
}) {
  return showDialog<DashboardSection>(
    context: context,
    builder: (_) =>
        _AddSectionDialog(bookmarksAlreadyPresent: bookmarksAlreadyPresent),
  );
}

class _AddSectionDialog extends StatefulWidget {
  const _AddSectionDialog({required this.bookmarksAlreadyPresent});
  final bool bookmarksAlreadyPresent;

  @override
  State<_AddSectionDialog> createState() => _AddSectionDialogState();
}

class _AddSectionDialogState extends State<_AddSectionDialog> {
  final _controller = TextEditingController();
  bool _addingBookmarks = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Add section'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: !widget.bookmarksAlreadyPresent ? false : true,
            decoration: const InputDecoration(
              labelText: 'Section name',
              hintText: 'e.g. Work, Media, Entertainment',
            ),
            onChanged: (_) => setState(() => _addingBookmarks = false),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.bookmarks_outlined,
              color: widget.bookmarksAlreadyPresent ? cs.outline : cs.primary,
            ),
            title: Text(
              'My Bookmarks',
              style: TextStyle(
                color: widget.bookmarksAlreadyPresent ? cs.outline : null,
              ),
            ),
            subtitle: Text(
              widget.bookmarksAlreadyPresent
                  ? 'Already on dashboard'
                  : 'Re-add the bookmarks section',
              style: const TextStyle(fontSize: 12),
            ),
            selected: _addingBookmarks,
            selectedTileColor: cs.primaryContainer.withValues(alpha: 0.3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            enabled: !widget.bookmarksAlreadyPresent,
            onTap: () => setState(() {
              _addingBookmarks = !_addingBookmarks;
              if (_addingBookmarks) _controller.clear();
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_addingBookmarks) {
              Navigator.pop(
                  context,
                  DashboardSection(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    name: 'My Bookmarks',
                    isBookmarks: true,
                  ));
            } else {
              final name = _controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(
                  context,
                  DashboardSection(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    name: name,
                  ));
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
