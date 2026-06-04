import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/models/user_credential.dart';
import '../../providers/server_providers.dart';
import '../../providers/settings_providers.dart';
import '../../services/auth_service.dart';
import '../../services/platform/storage_permission_service.dart';

// ── Main wizard widget ─────────────────────────────────────────────────────────

/// Full setup wizard (first-run) and re-runnable permissions wizard (from Settings).
///
/// First-run flow (isRerun: false) — 8 steps:
///   Welcome → Server name → Admin credentials → Source directories →
///   Notifications → Battery → Keep-alive tips → Done ✓
///
/// Re-run from Settings (isRerun: true) — 4 steps:
///   Notifications → Battery → Keep-alive tips → Done ✓
class WelcomeScreen extends ConsumerStatefulWidget {
  final bool isRerun;
  const WelcomeScreen({super.key, this.isRerun = false});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with WidgetsBindingObserver {
  late final PageController _pageCtrl;
  late final List<Widget Function(BuildContext)> _pages;
  int _page = 0;
  bool _finishing = false;

  // ── Draft configuration (first-run only, written to settings on completion) ──
  late final TextEditingController _serverNameCtrl;
  late final TextEditingController _usernameCtrl;
  final TextEditingController _passCtrl = TextEditingController();
  bool _passVisible = false;
  List<String> _directories = [];

  // ── Live permission status ────────────────────────────────────────────────────
  bool _notificationsGranted = false;
  bool _batteryIgnored = false;
  // Used to show the storage permission status badge on the directories page
  // (read by _refreshStatus; direct reads avoided to keep the page stateless).
  bool _storageGranted = false; // ignore: unused_field

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final settings = ref.read(settingsProvider);
    _serverNameCtrl = TextEditingController(text: settings.serverName);
    _usernameCtrl = TextEditingController(
      text: settings.users.isNotEmpty ? settings.users.first.username : 'admin',
    );
    _directories = List<String>.from(settings.sourceDirectories);
    _pageCtrl = PageController();
    _pages = widget.isRerun ? _permPages() : _fullPages();
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageCtrl.dispose();
    _serverNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    if (!Platform.isAndroid) return;
    final fg = ref.read(foregroundServiceProvider);
    final notifications = await fg.isNotificationPermissionGranted();
    final battery = await fg.isBatteryOptimizationIgnored();
    final storage = await StoragePermissionService.hasManageStoragePermission();
    if (!mounted) return;
    setState(() {
      _notificationsGranted = notifications;
      _batteryIgnored = battery;
      _storageGranted = storage;
    });
  }

  List<Widget Function(BuildContext)> _fullPages() => [
        _buildWelcomePage,
        _buildServerNamePage,
        _buildAdminUserPage,
        _buildDirectoriesPage,
        ..._permPages(),
      ];

  List<Widget Function(BuildContext)> _permPages() => [
        _buildNotificationsPage,
        _buildBatteryPage,
        _buildKeepAlivePage,
        _buildDonePage,
      ];

  bool get _isLast => _page == _pages.length - 1;

  void _goNext() => _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );

  void _goPrev() => _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );

  Future<void> _doFinish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      var settings = ref.read(settingsProvider);
      if (!widget.isRerun) {
        // Server name
        final name = _serverNameCtrl.text.trim();
        if (name.isNotEmpty) settings = settings.copyWith(serverName: name);

        // Admin user — update first user (seeded by SettingsService)
        final uname = _usernameCtrl.text.trim();
        if (uname.isNotEmpty) {
          final users = List<UserCredential>.from(settings.users);
          if (users.isEmpty) {
            if (_passCtrl.text.isNotEmpty) {
              users.add(UserCredential(
                username: uname,
                passwordHash: await compute(
                    AuthService.hashPassword, _passCtrl.text),
              ));
            }
          } else {
            final old = users.first;
            users[0] = old.copyWith(
              username: uname,
              passwordHash: _passCtrl.text.isNotEmpty
                  ? await compute(AuthService.hashPassword, _passCtrl.text)
                  : old.passwordHash,
            );
          }
          settings = settings.copyWith(users: users);
        }

        // Source directories
        if (_directories.isNotEmpty) {
          settings = settings.copyWith(sourceDirectories: _directories);
        }

        settings = settings.copyWith(onboardingCompleted: true);
      }
      await ref.read(settingsProvider.notifier).update(settings);
      // isRerun pops back to Settings; first-run Riverpod rebuild transitions home.
      if (widget.isRerun && mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  // ── Scaffold ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _page == 0 || widget.isRerun,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) _goPrev();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.isRerun,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.isRerun ? 'Background setup' : 'pc-ify setup'),
              Text(
                'Step ${_page + 1} of ${_pages.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          actions: [
            if (!widget.isRerun && !_isLast)
              TextButton(
                onPressed: () => _pageCtrl.animateToPage(
                  _pages.length - 1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                ),
                child: const Text('Skip all'),
              ),
          ],
        ),
        body: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (_page + 1) / _pages.length),
              duration: const Duration(milliseconds: 300),
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 3,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (ctx, i) => _pages[i](ctx),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    if (_page > 0 && !_isLast)
                      OutlinedButton(
                          onPressed: _goPrev, child: const Text('Back')),
                    const Spacer(),
                    if (_isLast)
                      FilledButton(
                        onPressed: _finishing ? null : _doFinish,
                        child: _finishing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5),
                              )
                            : Text(widget.isRerun ? 'Done' : 'Get started'),
                      )
                    else
                      FilledButton(onPressed: _goNext, child: const Text('Next')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page builders ──────────────────────────────────────────────────────────────

  Widget _buildWelcomePage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cast_connected, size: 72, color: cs.primary),
          const SizedBox(height: 24),
          Text(
            'Welcome to\npc-ify server',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'This app turns your Android device into a media server on your '
            'local network. The pc-ify client on any other device can then '
            'browse and stream your files.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(height: 1.6, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          const _InfoRow(icon: Icons.dns_outlined, text: 'Name your server and set credentials'),
          const _InfoRow(icon: Icons.folder_open, text: 'Choose folders to share'),
          const _InfoRow(
            icon: Icons.battery_saver_outlined,
            text: 'Configure permissions to stay alive in the background',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Text(
                  'Takes about 2 minutes.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerNamePage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.dns_outlined, size: 56, color: cs.primary),
          const SizedBox(height: 24),
          Text('Name your server',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'The client app shows this name to identify your server on the '
            'local network. You can always change it in Settings.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _serverNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Server name',
              hintText: 'e.g. Living Room Tablet',
              prefixIcon: Icon(Icons.label_outline),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminUserPage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.manage_accounts_outlined, size: 56, color: cs.primary),
          const SizedBox(height: 24),
          Text('Admin credentials',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'The client app uses these credentials to log in. Change the '
            'defaults to something secure.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _usernameCtrl,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passCtrl,
            obscureText: !_passVisible,
            decoration: InputDecoration(
              labelText: 'New password',
              hintText: 'Leave empty to keep existing password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                    _passVisible ? Icons.visibility_off : Icons.visibility),
                onPressed: () =>
                    setState(() => _passVisible = !_passVisible),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You can add more users at any time in Settings → Users.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectoriesPage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.folder_open, size: 56, color: cs.primary),
          const SizedBox(height: 24),
          Text('Source directories',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'Choose the folders that the client app can browse and stream. '
            'You can add or remove folders later in Settings.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          if (_directories.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.folder_off_outlined,
                      size: 40, color: cs.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(
                    'No directories added yet.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ..._directories.map((dir) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    leading:
                        Icon(Icons.folder_outlined, color: cs.primary),
                    title: Text(p.basename(dir),
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(dir,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'Remove',
                      onPressed: () =>
                          setState(() => _directories.remove(dir)),
                    ),
                  ),
                )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _pickDirectory,
              icon: const Icon(Icons.add),
              label: const Text('Add directory'),
            ),
          ),
          if (_directories.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'You can skip this step and add directories in Settings before '
              'starting the server.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickDirectory() async {
    if (Platform.isAndroid) {
      final ok = await StoragePermissionService.hasManageStoragePermission();
      if (!ok && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Storage access required'),
            content: const Text(
              'Tap "Open Settings", enable "Allow access to all files" for '
              'pc-ify server, then return and tap "Add directory" again.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings')),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
        await StoragePermissionService.requestManageStoragePermission();
        await _refreshStatus();
        return;
      }
    }
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null || !mounted) return;
    if (!_directories.contains(path)) setState(() => _directories.add(path));
  }

  Widget _buildNotificationsPage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_outlined,
              size: 56, color: cs.primary),
          const SizedBox(height: 24),
          Text('Allow notifications',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'A persistent notification appears while the server is running. '
            'Without it, Android is more likely to kill the server process '
            'when the app is in the background.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // ── Restricted-settings callout (Android 13+ / Samsung sideload) ──────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security_outlined,
                        size: 18, color: cs.onTertiaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sideloaded APK? Unlock first (Samsung / Android 13+)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onTertiaryContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Android blocks the notification permission dialog for '
                  'apps installed outside Google Play until you manually '
                  'unlock "Restricted settings". This is the most common '
                  'reason the notification never appears on Samsung OneUI.',
                  style: TextStyle(
                    color: cs.onTertiaryContainer,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                _NumberedStep(
                    n: 1,
                    text: 'Tap "Open app settings" below',
                    color: cs.onTertiaryContainer),
                _NumberedStep(
                    n: 2,
                    text: 'Tap ⋮ (three-dot menu, top-right corner)',
                    color: cs.onTertiaryContainer),
                _NumberedStep(
                    n: 3,
                    text: 'Tap "Allow restricted settings"',
                    color: cs.onTertiaryContainer),
                _NumberedStep(
                    n: 4,
                    text: 'Return here and tap "Allow notifications"',
                    color: cs.onTertiaryContainer),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _StatusBadge(label: 'Notifications', done: _notificationsGranted),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => StoragePermissionService.openAppSettings(),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open app settings'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _notificationsGranted
                      ? null
                      : () async {
                          await ref
                              .read(foregroundServiceProvider)
                              .requestNotificationPermission();
                          await _refreshStatus();
                        },
                  icon: Icon(_notificationsGranted
                      ? Icons.check
                      : Icons.notifications),
                  label: Text(_notificationsGranted
                      ? 'Granted ✓'
                      : 'Allow notifications'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryPage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.battery_saver, size: 56, color: cs.primary),
          const SizedBox(height: 24),
          Text('Disable battery optimisation',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'This is the single most important step. With battery '
            'optimisation active, Samsung, Xiaomi, OPPO, and Vivo devices '
            'kill the server within seconds of minimising the app — even '
            'when the foreground notification is shown.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(
            'Tapping "Allow unrestricted" shows a system dialog. Choose '
            '"Unrestricted" or "Allow background activity".',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _StatusBadge(
              label: 'Battery optimisation ignored', done: _batteryIgnored),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _batteryIgnored
                  ? null
                  : () async {
                      await ref
                          .read(foregroundServiceProvider)
                          .requestBatteryOptimizationExemption();
                      await _refreshStatus();
                    },
              icon: Icon(_batteryIgnored ? Icons.check : Icons.battery_saver),
              label: Text(_batteryIgnored
                  ? 'Exempted — good to go!'
                  : 'Allow unrestricted'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeepAlivePage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 56, color: cs.primary),
          const SizedBox(height: 24),
          Text('Keep the server alive',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'Some manufacturers add extra app-killing controls with no '
            'standard API. Two things help:',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          _TipCard(
            number: '1',
            title: 'Lock in Recent apps',
            body: 'Open the Recents screen, long-press the pc-ify server card, '
                'and select "Lock" or pin it. Swiping away a locked app does '
                'not kill it.',
            bgColor: cs.primaryContainer,
            fgColor: cs.onPrimaryContainer,
          ),
          const SizedBox(height: 12),
          _TipCard(
            number: '2',
            title: 'Enable Autostart (Samsung / Xiaomi / OPPO / Vivo)',
            body: 'In the app settings page, look for "Allow background '
                'activity", "Autostart", or "Unlimited" battery usage and '
                'enable it for pc-ify server.',
            bgColor: cs.secondaryContainer,
            fgColor: cs.onSecondaryContainer,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => StoragePermissionService.openAppSettings(),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open app settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonePage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _AnimatedCheckmark(),
            const SizedBox(height: 32),
            Text(
              widget.isRerun ? 'Settings updated' : "You're all set!",
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              widget.isRerun
                  ? 'Background permissions have been configured.'
                  : 'pc-ify server is ready. Tap "Get started" to open the '
                      'main screen, then press Start Server to begin sharing.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            if (!widget.isRerun) ...[
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 10),
                    _SummaryRow(
                      icon: Icons.dns_outlined,
                      label: 'Server name',
                      value: _serverNameCtrl.text.trim().isEmpty
                          ? '(default)'
                          : _serverNameCtrl.text.trim(),
                    ),
                    _SummaryRow(
                      icon: Icons.person_outline,
                      label: 'Admin user',
                      value: _usernameCtrl.text.trim().isEmpty
                          ? '(default)'
                          : _usernameCtrl.text.trim(),
                    ),
                    _SummaryRow(
                      icon: Icons.folder_outlined,
                      label: 'Directories',
                      value: _directories.isEmpty
                          ? 'None – add in Settings'
                          : '${_directories.length} folder${_directories.length == 1 ? '' : 's'}',
                      warn: _directories.isEmpty,
                    ),
                    _SummaryRow(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      value:
                          _notificationsGranted ? 'Allowed ✓' : 'Not granted',
                      warn: !_notificationsGranted,
                    ),
                    _SummaryRow(
                      icon: Icons.battery_saver,
                      label: 'Battery',
                      value: _batteryIgnored ? 'Unrestricted ✓' : 'Optimised',
                      warn: !_batteryIgnored,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: cs.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool done;
  const _StatusBadge({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: done ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: done ? cs.primary : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Text(
            done ? '$label: granted ✓' : label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: done ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  final int n;
  final String text;
  final Color color;
  const _NumberedStep(
      {required this.n, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$n.',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 13),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style:
                  TextStyle(color: color, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String number;
  final String title;
  final String body;
  final Color bgColor;
  final Color fgColor;
  const _TipCard({
    required this.number,
    required this.title,
    required this.body,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: fgColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: fgColor, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: fgColor,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(body,
                    style:
                        TextStyle(color: fgColor, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool warn;
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: warn ? cs.error : cs.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Animated checkmark ─────────────────────────────────────────────────────────

class _AnimatedCheckmark extends StatefulWidget {
  const _AnimatedCheckmark();

  @override
  State<_AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<_AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final circleScale = CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
        ).value;
        final checkProgress = CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.38, 0.88, curve: Curves.easeInOut),
        ).value;
        final pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.88, 1.0, curve: Curves.easeInOut),
          ),
        ).value;
        return Transform.scale(
          scale: circleScale * pulse,
          child: SizedBox(
            width: 130,
            height: 130,
            child: CustomPaint(
              painter: _CheckPainter(
                progress: checkProgress,
                circleColor: cs.primaryContainer,
                ringColor: cs.primary.withValues(alpha: 0.35),
                checkColor: cs.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color circleColor;
  final Color ringColor;
  final Color checkColor;

  const _CheckPainter({
    required this.progress,
    required this.circleColor,
    required this.ringColor,
    required this.checkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;

    // Filled circle
    canvas.drawCircle(c, r, Paint()..color = circleColor);
    // Subtle ring
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    if (progress <= 0) return;

    // Checkmark: two line segments (✓ shape)
    final cr = r * 0.54;
    final p1 = Offset(c.dx - cr * 0.52, c.dy + cr * 0.06);
    final p2 = Offset(c.dx - cr * 0.04, c.dy + cr * 0.54);
    final p3 = Offset(c.dx + cr * 0.64, c.dy - cr * 0.44);

    final seg1 = (p2 - p1).distance;
    final seg2 = (p3 - p2).distance;
    final drawn = progress * (seg1 + seg2);

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawn <= seg1) {
      final t = drawn / seg1;
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = (drawn - seg1) / seg2;
      path.lineTo(
        p2.dx + (p3.dx - p2.dx) * t,
        p2.dy + (p3.dy - p2.dy) * t,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = checkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      progress != old.progress ||
      circleColor != old.circleColor ||
      checkColor != old.checkColor;
}
