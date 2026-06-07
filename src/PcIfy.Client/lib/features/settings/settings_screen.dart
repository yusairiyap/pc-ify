import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/grid_density_helper.dart';
import '../../features/app_lock/app_lock_providers.dart';
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
  late int _thumbnailQuality;
  late int _pollIntervalSeconds;
  late AppLockType _lockType;
  late int _lockGrace;

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
    _thumbnailQuality = prefs.getInt('thumbnail_quality') ?? 50;
    _pollIntervalSeconds = prefs.getInt('dashboard_poll_interval') ?? 5;
    final lockService = ref.read(appLockServiceProvider);
    _lockType = lockService.getLockType();
    _lockGrace = lockService.gracePeriodSeconds;
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

  void _onThumbnailQualityChanged(int quality) {
    setState(() => _thumbnailQuality = quality);
    ref.read(sharedPrefsProvider).setInt('thumbnail_quality', quality);
  }

  void _onPollIntervalChanged(int seconds) {
    setState(() => _pollIntervalSeconds = seconds);
    ref.read(sharedPrefsProvider).setInt('dashboard_poll_interval', seconds);
    ref.read(dashboardPollIntervalProvider.notifier).state = seconds;
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
                const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thumbnail Quality',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 2),
                      Text(
                        'Higher quality improves sharpness on large screens but takes longer to generate',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 25, label: Text('Low')),
                            ButtonSegment(value: 50, label: Text('Medium')),
                            ButtonSegment(value: 75, label: Text('High')),
                            ButtonSegment(value: 100, label: Text('Ultra')),
                          ],
                          selected: {_thumbnailQuality},
                          onSelectionChanged: (v) =>
                              _onThumbnailQualityChanged(v.first),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Dashboard'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Update interval',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    'How often dashboard widgets refresh their data',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 5, label: Text('5s')),
                        ButtonSegment(value: 10, label: Text('10s')),
                        ButtonSegment(value: 30, label: Text('30s')),
                      ],
                      selected: {_pollIntervalSeconds},
                      onSelectionChanged: (v) =>
                          _onPollIntervalChanged(v.first),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Security'),
          _SecurityCard(
            lockType: _lockType,
            gracePeriodSeconds: _lockGrace,
            onLockTypeChanged: (t) => setState(() => _lockType = t),
            onGraceChanged: (s) => setState(() => _lockGrace = s),
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
            child: Column(
              children: [
                ListTile(
                  title: const Text('Server'),
                  subtitle: Text(
                    serverUrl.isEmpty ? 'Not configured' : serverUrl,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text('Log Out',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  leading: Icon(Icons.logout,
                      color: Theme.of(context).colorScheme.error),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('About'),
          _AboutCard(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Security card
// ---------------------------------------------------------------------------

class _SecurityCard extends ConsumerWidget {
  const _SecurityCard({
    required this.lockType,
    required this.gracePeriodSeconds,
    required this.onLockTypeChanged,
    required this.onGraceChanged,
  });

  final AppLockType lockType;
  final int gracePeriodSeconds;
  final ValueChanged<AppLockType> onLockTypeChanged;
  final ValueChanged<int> onGraceChanged;

  String get _lockLabel => switch (lockType) {
        AppLockType.biometric => 'Device Biometric / PIN',
        AppLockType.pin => 'Custom PIN',
        AppLockType.password => 'Password',
        AppLockType.none => '',
      };

  String _graceLabel(int s) =>
      s == 0 ? 'Immediately' : 'After ${s}s';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = lockType != AppLockType.none;
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('App Lock'),
            subtitle: Text(enabled
                ? _lockLabel
                : 'Require authentication to open the app'),
            value: enabled,
            onChanged: (on) {
              if (on) {
                _showTypeSheet(context, ref);
              } else {
                _disableLock(context, ref);
              }
            },
          ),
          if (enabled) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              title: const Text('Lock method'),
              subtitle: Text(_lockLabel),
              trailing: TextButton(
                onPressed: () => _showTypeSheet(context, ref),
                child: const Text('Change'),
              ),
            ),
            if (lockType == AppLockType.pin ||
                lockType == AppLockType.password) ...[
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                title: Text(lockType == AppLockType.pin
                    ? 'Change PIN'
                    : 'Change Password'),
                leading: const Icon(Icons.key_outlined),
                onTap: () {
                  final path = lockType == AppLockType.pin
                      ? '/settings/security/setup-pin?change=true'
                      : '/settings/security/setup-password?change=true';
                  context.push(path);
                },
              ),
            ],
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              title: const Text('Lock after'),
              subtitle: Text(_graceLabel(gracePeriodSeconds)),
              leading: const Icon(Icons.timer_outlined),
              onTap: () => _showGraceSheet(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showTypeSheet(BuildContext context, WidgetRef ref) async {
    final auth = LocalAuthentication();
    final biometricAvailable = await auth.isDeviceSupported();

    if (!context.mounted) return;

    final chosen = await showModalBottomSheet<AppLockType>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Choose lock method',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('Device Biometric / PIN'),
              subtitle: biometricAvailable
                  ? null
                  : const Text('Not available on this device'),
              enabled: biometricAvailable,
              onTap: () => Navigator.pop(context, AppLockType.biometric),
            ),
            ListTile(
              leading: const Icon(Icons.dialpad),
              title: const Text('Custom PIN (4 digits)'),
              onTap: () => Navigator.pop(context, AppLockType.pin),
            ),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Password'),
              onTap: () => Navigator.pop(context, AppLockType.password),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen == null || !context.mounted) return;

    if (chosen == AppLockType.biometric) {
      final ok = await auth.authenticate(
        localizedReason: 'Confirm your device credential to enable app lock',
        persistAcrossBackgrounding: true,
      );
      if (!ok || !context.mounted) return;
      final service = ref.read(appLockServiceProvider);
      await service.setLockType(AppLockType.biometric);
      ref.read(lockNotifierProvider.notifier).refreshType();
      onLockTypeChanged(AppLockType.biometric);
    } else if (chosen == AppLockType.pin) {
      context.push('/settings/security/setup-pin').then((_) {
        final t = ref.read(appLockServiceProvider).getLockType();
        onLockTypeChanged(t);
      });
    } else if (chosen == AppLockType.password) {
      context.push('/settings/security/setup-password').then((_) {
        final t = ref.read(appLockServiceProvider).getLockType();
        onLockTypeChanged(t);
      });
    }
  }

  Future<void> _disableLock(BuildContext context, WidgetRef ref) async {
    final service = ref.read(appLockServiceProvider);
    // Re-authenticate before disabling.
    if (lockType == AppLockType.biometric) {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Confirm to disable app lock',
        persistAcrossBackgrounding: true,
      );
      if (!ok || !context.mounted) return;
    } else {
      final confirmed = await _showCredentialDialog(context, service);
      if (!confirmed || !context.mounted) return;
    }
    await service.clearCredential();
    await service.setLockType(AppLockType.none);
    ref.read(lockNotifierProvider.notifier).refreshType();
    onLockTypeChanged(AppLockType.none);
  }

  Future<bool> _showCredentialDialog(
      BuildContext context, AppLockService service) async {
    final ctrl = TextEditingController();
    bool result = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm to disable'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: lockType == AppLockType.pin ? 'Enter PIN' : 'Enter password',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              result = await service.verifyCredential(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _showGraceSheet(BuildContext context, WidgetRef ref) async {
    double sliderVal = gracePeriodSeconds.toDouble();
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Lock after',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 16),
                Text(
                  sliderVal == 0
                      ? 'Immediately'
                      : 'After ${sliderVal.toInt()}s',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.headlineSmall,
                ),
                Slider(
                  value: sliderVal,
                  min: 0,
                  max: 300,
                  divisions: 60,
                  label: sliderVal == 0
                      ? 'Immediately'
                      : '${sliderVal.toInt()}s',
                  onChanged: (v) => setLocal(() => sliderVal = v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Immediately',
                        style: Theme.of(ctx).textTheme.bodySmall),
                    Text('5 min',
                        style: Theme.of(ctx).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final seconds = sliderVal.toInt();
                    await ref
                        .read(appLockServiceProvider)
                        .setGracePeriod(seconds);
                    onGraceChanged(seconds);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
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

class _AboutCard extends StatelessWidget {
  Future<void> _openGitHub() async {
    final uri = Uri.parse('https://github.com/yusairiyap/pc-ify');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('pc-ify',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Developed by Yusairi Yap',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              )),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openGitHub,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('github.com/yusairiyap/pc-ify'),
            ),
          ],
        ),
      ),
    );
  }
}
