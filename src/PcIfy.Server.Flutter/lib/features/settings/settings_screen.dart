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
        ],
      ),
    );
  }

  Future<void> _save() async {
    await ref.read(settingsProvider.notifier).update(_draft);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')));
      Navigator.of(context).pop();
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
