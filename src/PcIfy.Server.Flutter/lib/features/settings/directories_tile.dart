import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/models/app_settings.dart';

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
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    if (settings.sourceDirectories.contains(path)) return;
    final updated = List<String>.from(settings.sourceDirectories)..add(path);
    onChanged(settings.copyWith(sourceDirectories: updated));
  }
}
