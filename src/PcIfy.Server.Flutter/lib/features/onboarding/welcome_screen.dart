import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/server_providers.dart';
import '../../providers/settings_providers.dart';
import '../../services/platform/storage_permission_service.dart';

/// First-run setup wizard. Walks the user through the runtime permissions and
/// OEM settings the Android server needs to keep running in the background.
///
/// On non-Android platforms this screen is never shown (see app.dart), but it is
/// also safe to push from Settings to re-run the wizard.
class WelcomeScreen extends ConsumerStatefulWidget {
  /// When true, the "Finish" button just pops instead of marking onboarding
  /// complete (used when re-running the wizard from Settings).
  final bool isRerun;
  const WelcomeScreen({super.key, this.isRerun = false});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with WidgetsBindingObserver {
  final _controller = PageController();
  int _page = 0;

  bool _notificationsGranted = false;
  bool _batteryIgnored = false;
  bool _storageGranted = false;

  bool get _isAndroid => Platform.isAndroid;

  late final List<_Step> _steps = _buildSteps();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check after the user returns from a system settings screen.
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    if (!_isAndroid) return;
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

  List<_Step> _buildSteps() {
    return [
      const _Step(
        icon: Icons.cast_connected,
        title: 'Welcome to pc-ify server',
        body:
            'This app turns your device into a media server on your local '
            'network. To keep serving while the app is minimised or the screen '
            'is off, Android needs a few permissions. This quick setup walks '
            'you through them.',
      ),
      _Step(
        icon: Icons.notifications_active_outlined,
        title: 'Allow notifications',
        body:
            'A permanent notification shows while the server is running. '
            'Android 13+ requires you to allow notifications for it to appear — '
            'without it the server still runs, but you lose the at-a-glance '
            'status and the system is more likely to stop it.',
        statusLabel: 'Notifications',
        isDone: () => _notificationsGranted,
        actionLabel: 'Allow notifications',
        action: () async {
          await ref.read(foregroundServiceProvider).requestNotificationPermission();
          await _refreshStatus();
        },
      ),
      _Step(
        icon: Icons.battery_saver,
        title: 'Disable battery optimisation',
        body:
            'This is the most important step. With battery optimisation on, '
            'Android (and especially Samsung/Xiaomi/OPPO/Vivo) will kill the '
            'server soon after you leave the app. Allowing unrestricted '
            'background activity keeps it alive.',
        statusLabel: 'Battery optimisation ignored',
        isDone: () => _batteryIgnored,
        actionLabel: 'Allow unrestricted',
        action: () async {
          await ref
              .read(foregroundServiceProvider)
              .requestBatteryOptimizationExemption();
          await _refreshStatus();
        },
      ),
      _Step(
        icon: Icons.folder_open,
        title: 'Allow file access',
        body:
            'The server needs access to your files so it can share the folders '
            'you choose. Grant "All files access" so any source directory works.',
        statusLabel: 'All files access',
        isDone: () => _storageGranted,
        actionLabel: 'Grant access',
        action: () async {
          await StoragePermissionService.requestManageStoragePermission();
          await _refreshStatus();
        },
      ),
      _Step(
        icon: Icons.lock_open,
        title: 'Keep the app from being killed',
        body:
            'Some manufacturers add their own "Autostart" and aggressive '
            'app-killing settings that Android has no standard control for. To '
            'be safe:\n\n'
            '•  In Recent apps, lock pc-ify server so swiping away does not '
            'kill it.\n'
            '•  Open app settings below and enable Autostart / allow background '
            'activity if your device offers it.',
        actionLabel: 'Open app settings',
        action: () async {
          await StoragePermissionService.openAppSettings();
        },
      ),
    ];
  }

  bool get _isLast => _page == _steps.length - 1;

  Future<void> _finish() async {
    if (!widget.isRerun) {
      final settings = ref.read(settingsProvider);
      await ref
          .read(settingsProvider.notifier)
          .update(settings.copyWith(onboardingCompleted: true));
    }
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.isRerun,
        title: Text(widget.isRerun ? 'Background setup' : 'Setup'),
        actions: [
          if (!widget.isRerun && !_isLast)
            TextButton(
              onPressed: _finish,
              child: const Text('Skip'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _steps.length,
              itemBuilder: (context, i) => _StepView(
                step: _steps[i],
                refreshTrigger: _refreshSignal,
              ),
            ),
          ),
          // Page dots
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? cs.primary : cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      ),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_isLast
                        ? (widget.isRerun ? 'Done' : 'Get started')
                        : 'Next'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A counter that increments on every status refresh so step views rebuild
  // their status chips even though the step config is captured in a closure.
  int get _refreshSignal =>
      (_notificationsGranted ? 1 : 0) +
      (_batteryIgnored ? 2 : 0) +
      (_storageGranted ? 4 : 0);
}

class _Step {
  final IconData icon;
  final String title;
  final String body;
  final String? statusLabel;
  final bool Function()? isDone;
  final String? actionLabel;
  final Future<void> Function()? action;

  const _Step({
    required this.icon,
    required this.title,
    required this.body,
    this.statusLabel,
    this.isDone,
    this.actionLabel,
    this.action,
  });
}

class _StepView extends StatefulWidget {
  final _Step step;
  final int refreshTrigger;
  const _StepView({required this.step, required this.refreshTrigger});

  @override
  State<_StepView> createState() => _StepViewState();
}

class _StepViewState extends State<_StepView> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final step = widget.step;
    final done = step.isDone?.call() ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Icon(step.icon, size: 56, color: cs.primary),
          const SizedBox(height: 20),
          Text(step.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            step.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          if (step.statusLabel != null) ...[
            const SizedBox(height: 20),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: done
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: done ? cs.primary : cs.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      done ? '${step.statusLabel}: granted' : step.statusLabel!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (step.action != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: (_busy || done && step.statusLabel != null)
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await step.action!.call();
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(done && step.statusLabel != null
                      ? Icons.check
                      : Icons.open_in_new),
              label: Text(done && step.statusLabel != null
                  ? 'Done'
                  : step.actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
