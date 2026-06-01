import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/app_settings.dart';
import '../../providers/server_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/theme_providers.dart';
import 'directories_tile.dart';
import 'users_tile.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late AppSettings _draft;
  late final TextEditingController _portCtrl;
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(settingsProvider);
    _portCtrl = TextEditingController(text: '${_draft.port}');
    _nameCtrl = TextEditingController(text: _draft.serverName);
  }

  @override
  void dispose() {
    _portCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverState =
        ref.watch(serverStateProvider).asData?.value;
    final isRunning = serverState?.isRunning ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── General ──────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('General',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: TextFormField(
                          controller: _portCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Port'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (v) {
                            final port = int.tryParse(v);
                            if (port != null && port > 0 && port <= 65535) {
                              setState(() =>
                                  _draft = _draft.copyWith(port: port));
                            }
                          },
                        ),
                      ),
                      if (isRunning)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'Restart server to apply port change',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Server Name'),
                    onChanged: (v) =>
                        setState(() => _draft = _draft.copyWith(serverName: v)),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-start on launch'),
                    value: _draft.autoStart,
                    onChanged: (v) =>
                        setState(() => _draft = _draft.copyWith(autoStart: v)),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _draft.colorMode,
                    decoration:
                        const InputDecoration(labelText: 'Colour Mode'),
                    items: ['System', 'Dark', 'Light']
                        .map((m) =>
                            DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() =>
                          _draft = _draft.copyWith(colorMode: v));
                      _applyColorMode(v);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Directories ───────────────────────────────────────────────
          DirectoriesTile(
            settings: _draft,
            onChanged: (updated) => setState(() => _draft = updated),
          ),
          const SizedBox(height: 12),

          // ── Users ─────────────────────────────────────────────────────
          UsersTile(
            settings: _draft,
            onChanged: (updated) => setState(() => _draft = updated),
          ),
          const SizedBox(height: 12),

          // ── Import / Export ───────────────────────────────────────────
          _ImportExportCard(
            draft: _draft,
            onImported: (imported) => setState(() => _draft = imported),
          ),

          // ── Android disclaimer ────────────────────────────────────────
          if (Platform.isAndroid) ...[
            const SizedBox(height: 24),
            const _AndroidServerDisclaimerCard(),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final svc = ref.read(httpServerServiceProvider);

      // Stop first so the old server releases the port before settings change.
      await svc.stop();
      if (Platform.isAndroid) {
        await ref.read(foregroundServiceProvider).stop();
      }

      await ref.read(settingsProvider.notifier).update(_draft);

      // Restart if there is enough config to run.
      if (_draft.sourceDirectories.isNotEmpty && _draft.users.isNotEmpty) {
        await ref.read(httpServerServiceProvider).start(_draft.port);
        if (Platform.isAndroid) {
          await ref.read(foregroundServiceProvider).start(_draft.port);
        }
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyColorMode(String mode) {
    final current = ref.read(themeNotifierProvider);
    final themeMode = switch (mode) {
      'Dark' => ThemeMode.dark,
      'Light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    ref
        .read(themeNotifierProvider.notifier)
        .apply(themeMode, current.accentColor);
  }
}

// ── Import / Export Card ──────────────────────────────────────────────────────

class _ImportExportCard extends StatefulWidget {
  final AppSettings draft;
  final ValueChanged<AppSettings> onImported;

  const _ImportExportCard({required this.draft, required this.onImported});

  @override
  State<_ImportExportCard> createState() => _ImportExportCardState();
}

class _ImportExportCardState extends State<_ImportExportCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import / Export',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Back up or transfer settings as a ZIP file. '
              'Compatible with the legacy Windows server.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _export,
                  icon: const Icon(Icons.upload, size: 16),
                  label: const Text('Export'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _import,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Import'),
                ),
                if (_busy) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final jsonStr = const JsonEncoder.withIndent('  ')
          .convert(widget.draft.toJson());
      final jsonBytes = utf8.encode(jsonStr);

      final archive = Archive()
        ..addFile(ArchiveFile('settings.json', jsonBytes.length, jsonBytes));
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) throw Exception('ZIP encoding failed');

      final zipUint8 = Uint8List.fromList(zipBytes);

      if (Platform.isAndroid) {
        // On Android, file_picker writes via SAF ContentResolver when bytes is provided.
        await FilePicker.platform.saveFile(
          dialogTitle: 'Export settings',
          fileName: 'pcify-settings.zip',
          type: FileType.custom,
          allowedExtensions: ['zip'],
          bytes: zipUint8,
        );
        _showSnack('Settings exported.');
      } else {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Export settings',
          fileName: 'pcify-settings.zip',
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );
        if (path != null) {
          await File(path).writeAsBytes(zipBytes);
          _showSnack('Settings exported.');
        }
      }
    } catch (e) {
      _showSnack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      final archive =
          ZipDecoder().decodeBytes(result.files.single.bytes!);
      final entry = archive.findFile('settings.json');
      if (entry == null) {
        _showSnack('Invalid file: settings.json not found in ZIP.');
        return;
      }

      final jsonStr = utf8.decode(entry.content as List<int>);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final imported = AppSettings.fromJson(json);
      widget.onImported(imported);
      _showSnack('Settings imported. Review and tap Save to apply.');
    } catch (e) {
      _showSnack('Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ── Android server disclaimer ─────────────────────────────────────────────────

class _AndroidServerDisclaimerCard extends StatelessWidget {
  const _AndroidServerDisclaimerCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: cs.onSurfaceVariant, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Android notice\n\n'
                'On some devices — particularly those with aggressive battery '
                'optimisation (e.g. Samsung, Xiaomi, OPPO) — the server '
                'process may be killed by the system while running in the '
                'background, even when the foreground service notification is '
                'active. If clients lose connection unexpectedly, keep this '
                'app in the foreground or disable battery optimisation for it '
                'in your device settings.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
