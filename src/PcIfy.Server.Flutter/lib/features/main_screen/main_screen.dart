import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/server_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/theme_providers.dart';
import '../../services/ffmpeg_setup_service.dart';
import '../../services/http_server_service.dart';
import '../dialogs/ffmpeg_download_dialog.dart';
import '../settings/settings_screen.dart';
import 'log_table_widget.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  bool _startingOrStopping = false;
  Timer? _copyTimer;
  bool _showCopied = false;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(serverStateProvider);
    final settings = ref.watch(settingsProvider);
    final themeState = ref.watch(themeNotifierProvider);
    final isDark = themeState.mode == ThemeMode.dark ||
        (themeState.mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    final currentState = serverState.asData?.value ?? ServerState.stopped;

    return Scaffold(
      appBar: AppBar(
        title: const Text('pc-ify server'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDark ? 'Switch to Light' : 'Switch to Dark',
            onPressed: () {
              final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
              ref
                  .read(themeNotifierProvider.notifier)
                  .apply(newMode, themeState.accentColor);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusCard(
            state: currentState,
            showCopied: _showCopied,
            onCopyAddress: () => _copyAddress(currentState),
          ),
          const Divider(height: 1),
          const Expanded(child: LogTableWidget()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startingOrStopping ? null : () => _toggleServer(currentState, settings.port),
        icon: _startingOrStopping
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(currentState.isRunning ? Icons.stop : Icons.play_arrow),
        label: Text(currentState.isRunning ? 'Stop Server' : 'Start Server'),
        backgroundColor: currentState.isRunning
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: currentState.isRunning
            ? Theme.of(context).colorScheme.onErrorContainer
            : Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }

  Future<void> _toggleServer(ServerState state, int port) async {
    final settings = ref.read(settingsProvider);
    if (!state.isRunning) {
      if (settings.sourceDirectories.isEmpty) {
        _showSnack('Add at least one source directory in Settings first.');
        return;
      }
      if (settings.users.isEmpty) {
        _showSnack('Add at least one user in Settings first.');
        return;
      }
    }

    setState(() => _startingOrStopping = true);
    try {
      final svc = ref.read(httpServerServiceProvider);
      if (state.isRunning) {
        await svc.stop();
        if (Platform.isAndroid) {
          await ref.read(foregroundServiceProvider).stop();
        }
      } else {
        if ((Platform.isWindows || Platform.isMacOS) &&
            !FFmpegSetupService.isAvailable &&
            mounted) {
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const FfmpegDownloadDialog(),
          );
        }
        await svc.start(settings.port);
        if (Platform.isAndroid) {
          await ref.read(foregroundServiceProvider).start(settings.port);
        }
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _startingOrStopping = false);
    }
  }

  void _copyAddress(ServerState state) {
    if (!state.isRunning || state.port == null) return;
    final ip = state.ipAddresses.isNotEmpty
        ? state.ipAddresses.first
        : 'localhost';
    Clipboard.setData(ClipboardData(text: ip));
    setState(() => _showCopied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showCopied = false);
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _StatusCard extends StatelessWidget {
  final ServerState state;
  final bool showCopied;
  final VoidCallback onCopyAddress;

  const _StatusCard({
    required this.state,
    required this.showCopied,
    required this.onCopyAddress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRunning = state.isRunning;

    final addressText = isRunning && state.port != null
        ? state.ipAddresses.isNotEmpty
            ? state.ipAddresses
                .map((ip) => '$ip:${state.port}')
                .join('  |  ')
            : 'localhost:${state.port}'
        : '—';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Status chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isRunning
                  ? Colors.green.withValues(alpha: 0.2)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isRunning ? Colors.green : colorScheme.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRunning ? Colors.green : colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isRunning ? 'Running' : 'Stopped',
                  style: TextStyle(
                    color: isRunning ? Colors.green : colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Address
          Expanded(
            child: Text(
              addressText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Copy button
          if (isRunning)
            Tooltip(
              message: showCopied ? 'Copied!' : 'Copy address',
              child: IconButton(
                icon: Icon(
                  showCopied ? Icons.check : Icons.copy,
                  size: 18,
                ),
                onPressed: onCopyAddress,
              ),
            ),
        ],
      ),
    );
  }
}
