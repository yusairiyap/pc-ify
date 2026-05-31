import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/models/app_settings.dart';
import '../../services/platform/storage_permission_service.dart';

class DirectoriesTile extends StatelessWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;

  const DirectoriesTile({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Source Directories',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _addDirectory(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (settings.sourceDirectories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No directories configured.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ...settings.sourceDirectories.map((dir) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(dir,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'Remove',
                      onPressed: () {
                        final updated = List<String>.from(
                            settings.sourceDirectories)
                          ..remove(dir);
                        onChanged(
                            settings.copyWith(sourceDirectories: updated));
                      },
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _addDirectory(BuildContext context) async {
    if (Platform.isAndroid) {
      final granted = await StoragePermissionService.hasManageStoragePermission();
      if (!granted) {
        if (!context.mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Storage access required'),
            content: const Text(
              'To serve files from any folder, this app needs the '
              '"Allow access to all files" permission.\n\n'
              'Tap Open Settings, enable the permission for pc-ify server, '
              'then return here and tap Add again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        if (proceed != true || !context.mounted) return;
        await StoragePermissionService.requestManageStoragePermission();
        return;
      }
    }

    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    if (settings.sourceDirectories.contains(path)) return;
    final updated = List<String>.from(settings.sourceDirectories)..add(path);
    onChanged(settings.copyWith(sourceDirectories: updated));
  }
}
