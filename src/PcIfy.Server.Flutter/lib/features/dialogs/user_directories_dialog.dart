import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../core/models/user_credential.dart';

class UserDirectoriesDialog extends StatefulWidget {
  final UserCredential user;
  final List<String> allDirectories;

  const UserDirectoriesDialog({
    super.key,
    required this.user,
    required this.allDirectories,
  });

  @override
  State<UserDirectoriesDialog> createState() => _UserDirectoriesDialogState();
}

class _UserDirectoriesDialogState extends State<UserDirectoriesDialog> {
  late List<bool> _checked;

  @override
  void initState() {
    super.initState();
    // Empty allowedDirectories = unrestricted = all checked.
    _checked = widget.allDirectories.map((dir) {
      if (widget.user.allowedDirectories.isEmpty) return true;
      return widget.user.allowedDirectories
          .any((d) => d.toLowerCase() == dir.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Directory Access\n${widget.user.username}',
          style: Theme.of(context).textTheme.titleMedium),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Uncheck directories to restrict access. '
              'All checked = unrestricted.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            ...List.generate(widget.allDirectories.length, (i) {
              final dir = widget.allDirectories[i];
              return CheckboxListTile(
                dense: true,
                title: Text(p.basename(dir)),
                subtitle: Text(
                  dir,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: _checked[i],
                onChanged: (v) => setState(() => _checked[i] = v ?? false),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    final allChecked = _checked.every((c) => c);
    if (allChecked) {
      // All checked = unrestricted = empty list
      Navigator.of(context).pop(<String>[]);
    } else {
      final selected = <String>[];
      for (var i = 0; i < widget.allDirectories.length; i++) {
        if (_checked[i]) selected.add(widget.allDirectories[i]);
      }
      Navigator.of(context).pop(selected);
    }
  }
}
