import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import '../../providers/services_providers.dart';
import '../../providers/theme_providers.dart';
import '../../services/import_export_service.dart';

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  // Export state
  bool _exportSettings = true;
  bool _exportBookmarks = true;
  bool _exportFolderBgs = true;
  bool _exportThumbnails = false;
  bool _isExporting = false;

  // Import state
  String? _selectedZipPath;
  String? _selectedZipName;
  ImportPreview? _zipPreview;
  bool _importSettings = true;
  bool _importBookmarks = true;
  bool _importFolderBgs = true;
  bool _importThumbnails = false;
  bool _isInspecting = false;
  bool _isImporting = false;

  Future<void> _doExport() async {
    setState(() => _isExporting = true);
    try {
      final file = await ref.read(importExportServiceProvider).exportToZip(
            appSettings: _exportSettings,
            bookmarks: _exportBookmarks,
            folderBackgrounds: _exportFolderBgs,
            thumbnailCache: _exportThumbnails,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to ${file.path.split('/').last}'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFilex.open(file.path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    setState(() {
      _selectedZipPath = path;
      _selectedZipName = result.files.single.name;
      _zipPreview = null;
      _isInspecting = true;
    });

    try {
      final preview =
          await ref.read(importExportServiceProvider).inspectZip(path);
      if (!mounted) return;
      setState(() {
        _zipPreview = preview;
        _importSettings = preview.hasAppSettings;
        _importBookmarks = preview.hasBookmarks;
        _importFolderBgs = preview.folderBackgroundCount > 0;
        _importThumbnails = preview.thumbnailCacheFileCount > 0;
        _isInspecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isInspecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read ZIP: $e')),
      );
    }
  }

  Future<void> _doImport() async {
    if (_selectedZipPath == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Overwrite existing data?'),
        content: const Text(
          'Importing will replace your current settings, bookmarks, and/or folder backgrounds. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isImporting = true);
    try {
      await ref.read(importExportServiceProvider).importFromZip(
            zipPath: _selectedZipPath!,
            appSettings: _importSettings,
            bookmarks: _importBookmarks,
            folderBackgrounds: _importFolderBgs,
            thumbnailCache: _importThumbnails,
          );
      if (!mounted) return;

      if (_importSettings) {
        ref.invalidate(themeNotifierProvider);
        ref.invalidate(videoFitProvider);
        ref.invalidate(videoRepeatProvider);
      }
      if (_importBookmarks) {
        ref.invalidate(bookmarksProvider);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import complete')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  bool get _canImport {
    if (_selectedZipPath == null || _isImporting || _isInspecting) return false;
    return _importSettings || _importBookmarks || _importFolderBgs || _importThumbnails;
  }

  @override
  Widget build(BuildContext context) {
    final preview = _zipPreview;
    return Scaffold(
      appBar: AppBar(title: const Text('Import / Export')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Export ──────────────────────────────────────────────────
          const _SectionLabel('Export'),
          Card(
            child: Column(
              children: [
                CheckboxListTile(
                  title: const Text('App Settings'),
                  subtitle: const Text('Theme, accent color, grid density, playback'),
                  value: _exportSettings,
                  onChanged: (v) => setState(() => _exportSettings = v!),
                ),
                CheckboxListTile(
                  title: const Text('Bookmarks'),
                  value: _exportBookmarks,
                  onChanged: (v) => setState(() => _exportBookmarks = v!),
                ),
                CheckboxListTile(
                  title: const Text('Folder Backgrounds'),
                  subtitle: const Text('Per-folder background images and crop settings'),
                  value: _exportFolderBgs,
                  onChanged: (v) => setState(() => _exportFolderBgs = v!),
                ),
                CheckboxListTile(
                  title: const Text('Thumbnail Cache'),
                  subtitle: const Text('Optional — may be large'),
                  value: _exportThumbnails,
                  onChanged: (v) => setState(() => _exportThumbnails = v!),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isExporting ? null : _doExport,
                      child: _isExporting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Export'),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Import ──────────────────────────────────────────────────
          const _SectionLabel('Import'),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_zip_outlined),
                  title: Text(_selectedZipName ?? 'No file selected'),
                  subtitle: _selectedZipName != null ? null : const Text('Select a .zip file exported from pc-ify'),
                  trailing: TextButton(
                    onPressed: _isImporting ? null : _pickFile,
                    child: const Text('Select file'),
                  ),
                ),
                if (_isInspecting)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: LinearProgressIndicator(),
                  ),
                if (preview != null) ...[
                  // Warning banner
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Importing will overwrite existing data.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (preview.hasAppSettings)
                    CheckboxListTile(
                      title: const Text('App Settings'),
                      subtitle: const Text('Theme, accent color, grid density, playback'),
                      value: _importSettings,
                      onChanged: (v) => setState(() => _importSettings = v!),
                    ),
                  if (preview.hasBookmarks)
                    CheckboxListTile(
                      title: const Text('Bookmarks'),
                      value: _importBookmarks,
                      onChanged: (v) => setState(() => _importBookmarks = v!),
                    ),
                  if (preview.folderBackgroundCount > 0)
                    CheckboxListTile(
                      title: const Text('Folder Backgrounds'),
                      subtitle: Text('${preview.folderBackgroundCount} folder${preview.folderBackgroundCount == 1 ? '' : 's'}'),
                      value: _importFolderBgs,
                      onChanged: (v) => setState(() => _importFolderBgs = v!),
                    ),
                  if (preview.thumbnailCacheFileCount > 0)
                    CheckboxListTile(
                      title: const Text('Thumbnail Cache'),
                      subtitle: Text('${preview.thumbnailCacheFileCount} file${preview.thumbnailCacheFileCount == 1 ? '' : 's'}'),
                      value: _importThumbnails,
                      onChanged: (v) => setState(() => _importThumbnails = v!),
                    ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canImport ? _doImport : null,
                      child: _isImporting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Import'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
