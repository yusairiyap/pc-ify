import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/dashboard_providers.dart'
    show bookmarksProvider, dashboardLayoutProvider;
import '../../providers/services_providers.dart';
import '../../providers/theme_providers.dart';
import '../../services/backup_restore_service.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _exportBookmarks = true;
  bool _exportBookmarkFolderPrefs = true;
  bool _exportOtherFolderPrefs = true;
  bool _exportSettings = true;
  bool _exportDashboardLayout = true;
  bool _isExporting = false;
  bool _isImporting = false;

  bool get _nothingSelected =>
      !_exportBookmarks &&
      !_exportBookmarkFolderPrefs &&
      !_exportOtherFolderPrefs &&
      !_exportSettings &&
      !_exportDashboardLayout;

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      final service = ref.read(backupRestoreServiceProvider);
      final data = await service.collectBackup(
        includeBookmarks: _exportBookmarks,
        includeBookmarkFolderPrefs: _exportBookmarkFolderPrefs,
        includeOtherFolderPrefs: _exportOtherFolderPrefs,
        includeSettings: _exportSettings,
        includeDashboardLayout: _exportDashboardLayout,
      );
      final path = await service.exportToFile(data);
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup saved to $path')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _import() async {
    setState(() => _isImporting = true);
    BackupData? data;
    try {
      data = await ref.read(backupRestoreServiceProvider).importFromFile();
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
    if (!mounted || data == null) return;
    await _showRestoreDialog(data);
  }

  Future<void> _showRestoreDialog(BackupData data) async {
    bool restoreBookmarks = data.hasBookmarks;
    bool restoreBookmarkFolderPrefs = data.hasBookmarkFolderPrefs;
    bool restoreOtherFolderPrefs = data.hasOtherFolderPrefs;
    bool restoreSettings = data.hasSettings;
    final hasDashboardLayout =
        data.settings?.containsKey('dashboard_layout_v1') ?? false;
    bool restoreDashboardLayout = hasDashboardLayout;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Restore Backup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backup from ${_formatDate(data.createdAt)}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                const Text('Select what to restore:'),
                const SizedBox(height: 4),
                CheckboxListTile(
                  title: const Text('Bookmarks'),
                  subtitle: data.bookmarks != null
                      ? Text('${data.bookmarks!.length} item(s)')
                      : const Text('Not in backup'),
                  value: restoreBookmarks,
                  onChanged: data.hasBookmarks
                      ? (v) => setDialogState(() => restoreBookmarks = v!)
                      : null,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Bookmark folder backgrounds'),
                  subtitle: data.hasBookmarkFolderPrefs
                      ? Text(
                          '${data.bookmarkFolderPrefs!.length} background(s)')
                      : const Text('Not in backup'),
                  value: restoreBookmarkFolderPrefs,
                  onChanged: data.hasBookmarkFolderPrefs
                      ? (v) =>
                          setDialogState(() => restoreBookmarkFolderPrefs = v!)
                      : null,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Other folder backgrounds'),
                  subtitle: data.hasOtherFolderPrefs
                      ? Text('${data.otherFolderPrefs!.length} background(s)')
                      : const Text('Not in backup'),
                  value: restoreOtherFolderPrefs,
                  onChanged: data.hasOtherFolderPrefs
                      ? (v) =>
                          setDialogState(() => restoreOtherFolderPrefs = v!)
                      : null,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('App settings'),
                  subtitle:
                      !data.hasSettings ? const Text('Not in backup') : null,
                  value: restoreSettings,
                  onChanged: data.hasSettings
                      ? (v) => setDialogState(() => restoreSettings = v!)
                      : null,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Home Widgets placement'),
                  subtitle: !hasDashboardLayout
                      ? const Text('Not in backup')
                      : null,
                  value: restoreDashboardLayout,
                  onChanged: hasDashboardLayout
                      ? (v) => setDialogState(
                          () => restoreDashboardLayout = v!)
                      : null,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bookmarks are merged with your existing list — '
                  'nothing is deleted.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isImporting = true);
    try {
      final service = ref.read(backupRestoreServiceProvider);
      await service.restoreBackup(
        data,
        restoreBookmarks: restoreBookmarks,
        restoreBookmarkFolderPrefs: restoreBookmarkFolderPrefs,
        restoreOtherFolderPrefs: restoreOtherFolderPrefs,
        restoreSettings: restoreSettings,
        restoreDashboardLayout: restoreDashboardLayout,
      );

      // Propagate restored settings to live providers immediately.
      if (restoreSettings && data.settings != null) {
        final s = data.settings!;
        final themeModeStr = s['theme_mode'] as String?;
        final accentColorInt = s['accent_color'] as int?;
        if (themeModeStr != null || accentColorInt != null) {
          final current = ref.read(themeNotifierProvider);
          final newMode = switch (themeModeStr) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => current.mode,
          };
          final newColor = accentColorInt != null
              ? Color(accentColorInt)
              : current.accentColor;
          await ref
              .read(themeNotifierProvider.notifier)
              .apply(newMode, newColor);
        }
        if (s.containsKey('video_fit_mode')) {
          ref.read(videoFitProvider.notifier).state =
              switch (s['video_fit_mode'] as String) {
            'cover' => BoxFit.cover,
            'fill' => BoxFit.fill,
            _ => BoxFit.contain,
          };
        }
        if (s.containsKey('video_auto_repeat')) {
          ref.read(videoRepeatProvider.notifier).state =
              s['video_auto_repeat'] as bool;
        }
      }

      // Signal persistent screens (HomeScreen) to reload their folder backgrounds.
      if (restoreBookmarkFolderPrefs || restoreOtherFolderPrefs) {
        ref.read(folderPrefsVersionProvider.notifier).update((v) => v + 1);
      }
      // Refresh the bookmark list on HomeScreen if bookmarks were restored.
      if (restoreBookmarks) {
        ref.invalidate(bookmarksProvider);
      }
      // Refresh the dashboard layout live so it reflects immediately.
      if (restoreDashboardLayout) {
        ref.invalidate(dashboardLayoutProvider);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restored successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${_p(dt.month)}-${_p(dt.day)} ${_p(dt.hour)}:${_p(dt.minute)}';

  String _p(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final isLoading = _isExporting || _isImporting;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionLabel('EXPORT'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text('Bookmarks'),
                    subtitle: const Text('Saved folder shortcuts'),
                    value: _exportBookmarks,
                    onChanged: (v) => setState(() => _exportBookmarks = v!),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  CheckboxListTile(
                    title: const Text('Bookmark folder backgrounds'),
                    subtitle: const Text(
                        'Background images and videos set for bookmarked folders'),
                    value: _exportBookmarkFolderPrefs,
                    onChanged: (v) =>
                        setState(() => _exportBookmarkFolderPrefs = v!),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  CheckboxListTile(
                    title: const Text('Other folder backgrounds'),
                    subtitle: const Text(
                        'Home screen and individual browsed folder backgrounds'),
                    value: _exportOtherFolderPrefs,
                    onChanged: (v) =>
                        setState(() => _exportOtherFolderPrefs = v!),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  CheckboxListTile(
                    title: const Text('App settings'),
                    subtitle:
                        const Text('Theme, playback and display preferences'),
                    value: _exportSettings,
                    onChanged: (v) => setState(() => _exportSettings = v!),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  CheckboxListTile(
                    title: const Text('Home Widgets placement'),
                    subtitle: const Text(
                        'Dashboard sections, widget order and sizes'),
                    value: _exportDashboardLayout,
                    onChanged: (v) =>
                        setState(() => _exportDashboardLayout = v!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isLoading || _nothingSelected ? null : _export,
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: const Text('Export Backup'),
            ),
          ),
          const SizedBox(height: 32),
          const _SectionLabel('IMPORT'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose a previously exported backup file to restore your data.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Folder backgrounds are only usable when connected to the same server.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: isLoading ? null : _import,
              icon: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: const Text('Choose Backup File…'),
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
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
