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
  late ThemeMode _selectedMode;
  late Color _selectedAccent;
  late GridDensity _selectedDensity;

  @override
  void initState() {
    super.initState();
    final themeState = ref.read(themeNotifierProvider);
    _selectedMode = themeState.mode;
    _selectedAccent = themeState.accentColor;
    _selectedDensity = GridDensityHelper.fromString(
        ref.read(sharedPrefsProvider).getString('grid_density') ?? 'normal');
  }

  Future<void> _apply() async {
    await ref.read(themeNotifierProvider.notifier).apply(_selectedMode, _selectedAccent);
    await ref
        .read(sharedPrefsProvider)
        .setString('grid_density', _selectedDensity.name);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Settings applied')));
    }
  }

  Future<void> _logout() async {
    await ref.read(authTokenServiceProvider).clearToken();
    if (mounted) context.go('/setup');
  }

  Future<void> _changeServer() async {
    await ref.read(authTokenServiceProvider).clearToken();
    if (mounted) context.go('/setup');
  }

  @override
  Widget build(BuildContext context) {
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
                    value: _selectedMode,
                    isExpanded: true,
                    onChanged: (v) => setState(() => _selectedMode = v!),
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
                        final selected = _selectedAccent == color;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedAccent = color),
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
                    onChanged: (v) => setState(() => _selectedDensity = v!),
                    items: GridDensity.values
                        .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(GridDensityHelper.label(d))))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _apply,
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
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
                  trailing: TextButton(
                    onPressed: _changeServer,
                    child: const Text('Change'),
                  ),
                ),
              ],
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
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
