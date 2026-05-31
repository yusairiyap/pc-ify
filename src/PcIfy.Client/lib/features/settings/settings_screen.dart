import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/grid_density_helper.dart';
import '../../providers/services_providers.dart';
import '../../providers/theme_providers.dart';
import '../../services/theme_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late GridDensity _selectedDensity;
  late bool _alwaysExternal;
  late BoxFit _videoFit;
  late bool _videoRepeat;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    _selectedDensity = GridDensityHelper.fromString(
        prefs.getString('grid_density') ?? 'normal');
    _alwaysExternal = prefs.getBool('always_external_player') ?? false;
    _videoFit = switch (prefs.getString('video_fit_mode') ?? 'contain') {
      'cover' => BoxFit.cover,
      'fill' => BoxFit.fill,
      _ => BoxFit.contain,
    };
    _videoRepeat = prefs.getBool('video_auto_repeat') ?? false;
  }

  Future<void> _onThemeModeChanged(ThemeMode mode) async {
    final current = ref.read(themeNotifierProvider);
    await ref.read(themeNotifierProvider.notifier).apply(mode, current.accentColor);
  }

  Future<void> _onAccentChanged(Color color) async {
    final current = ref.read(themeNotifierProvider);
    await ref.read(themeNotifierProvider.notifier).apply(current.mode, color);
  }

  void _onDensityChanged(GridDensity density) {
    setState(() => _selectedDensity = density);
    ref.read(sharedPrefsProvider).setString('grid_density', density.name);
  }

  Future<void> _onAlwaysExternalChanged(bool value) async {
    setState(() => _alwaysExternal = value);
    await ref.read(sharedPrefsProvider).setBool('always_external_player', value);
  }

  void _onVideoFitChanged(BoxFit fit) {
    setState(() => _videoFit = fit);
    final s = switch (fit) {
      BoxFit.cover => 'cover',
      BoxFit.fill => 'fill',
      _ => 'contain',
    };
    ref.read(sharedPrefsProvider).setString('video_fit_mode', s);
    ref.read(videoFitProvider.notifier).state = fit;
  }

  Future<void> _onVideoRepeatChanged(bool value) async {
    setState(() => _videoRepeat = value);
    await ref.read(sharedPrefsProvider).setBool('video_auto_repeat', value);
    ref.read(videoRepeatProvider.notifier).state = value;
  }

  Future<void> _logout() async {
    await ref.read(authTokenServiceProvider).clearToken();
    if (mounted) context.go('/setup');
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeNotifierProvider);
    final serverUrl = ref.read(connectionServiceProvider).baseUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionLabel('Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  DropdownButton<ThemeMode>(
                    value: themeState.mode,
                    isExpanded: true,
                    onChanged: (v) => _onThemeModeChanged(v!),
                    items: const [
                      DropdownMenuItem(
                          value: ThemeMode.system, child: Text('System')),
                      DropdownMenuItem(
                          value: ThemeMode.light, child: Text('Light')),
                      DropdownMenuItem(
                          value: ThemeMode.dark, child: Text('Dark')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Accent Color',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ThemeService.presetColors.map((color) {
                        final selected = themeState.accentColor == color;
                        return GestureDetector(
                          onTap: () => _onAccentChanged(color),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: CircleAvatar(
                              backgroundColor: color,
                              radius: 20,
                              child: selected
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 18)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Grid Density',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  DropdownButton<GridDensity>(
                    value: _selectedDensity,
                    isExpanded: true,
                    onChanged: (v) => _onDensityChanged(v!),
                    items: GridDensity.values
                        .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(GridDensityHelper.label(d))))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Playback'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Always open in external player'),
                  subtitle: const Text(
                      'Skip the built-in player and send videos directly to another app'),
                  value: _alwaysExternal,
                  onChanged: _onAlwaysExternalChanged,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('Auto-repeat video'),
                  subtitle: const Text('Loop the video when it ends'),
                  value: _videoRepeat,
                  onChanged: _onVideoRepeatChanged,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Video Size',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      DropdownButton<BoxFit>(
                        value: _videoFit,
                        isExpanded: true,
                        onChanged: (v) => _onVideoFitChanged(v!),
                        items: const [
                          DropdownMenuItem(
                              value: BoxFit.contain,
                              child: Text('Fit to Screen')),
                          DropdownMenuItem(
                              value: BoxFit.cover,
                              child: Text('Crop to Fit')),
                          DropdownMenuItem(
                              value: BoxFit.fill, child: Text('Stretch')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Connection'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Server'),
                  subtitle: Text(
                    serverUrl.isEmpty ? 'Not configured' : serverUrl,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Data'),
          Card(
            child: ListTile(
              title: const Text('Backup & Restore'),
              subtitle: const Text(
                  'Export or import bookmarks, backgrounds and settings'),
              leading: const Icon(Icons.backup),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/settings/backup-restore'),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Account'),
          Card(
            child: ListTile(
              title: Text('Log Out',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              leading: Icon(Icons.logout,
                  color: Theme.of(context).colorScheme.error),
              onTap: _logout,
            ),
          ),
          if (Platform.isAndroid) ...[
            const SizedBox(height: 24),
            _AndroidDisclaimerCard(),
          ],
        ],
      ),
    );
  }
}

class _AndroidDisclaimerCard extends StatelessWidget {
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
                'On certain devices — particularly those with aggressive battery '
                'optimisation (e.g. Samsung, Xiaomi, OPPO) — the server app may '
                'be killed by the system when running in the background, causing '
                'the connection to drop unexpectedly.\n\n'
                'Persistent background notifications may also not appear on some '
                'devices regardless of permission settings.\n\n'
                'For a reliable connection, keep the server app in the foreground, '
                'or disable battery optimisation for it in your device settings.',
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
