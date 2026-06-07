import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/control_status.dart';
import '../../../core/models/dashboard_models.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/services_providers.dart';

const _iconMap = <String, IconData>{
  'chrome':     Icons.language,
  'firefox':    Icons.travel_explore,
  'edge':       Icons.explore,
  'safari':     Icons.public,
  'vscode':     Icons.code,
  'steam':      Icons.sports_esports,
  'discord':    Icons.chat_bubble_outline,
  'spotify':    Icons.music_note,
  'notepad':    Icons.edit_note,
  'word':       Icons.description,
  'excel':      Icons.table_chart,
  'powerpoint': Icons.slideshow,
  'vlc':        Icons.play_circle_outline,
  'terminal':   Icons.terminal,
  'explorer':   Icons.folder_open,
  'calculator': Icons.calculate,
  'settings':   Icons.settings,
  'photos':     Icons.photo_library,
  'mail':       Icons.mail_outline,
  'calendar':   Icons.calendar_today,
};

IconData _iconFor(String? key) =>
    key != null ? (_iconMap[key.toLowerCase()] ?? Icons.apps) : Icons.apps;

class AppLauncherCard extends ConsumerStatefulWidget {
  const AppLauncherCard({super.key, required this.hasBg, required this.size, this.badge});
  final bool hasBg;
  final WidgetSize size;
  final Widget? badge;

  @override
  ConsumerState<AppLauncherCard> createState() => _AppLauncherCardState();
}

class _AppLauncherCardState extends ConsumerState<AppLauncherCard> {

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final pathCtrl = TextEditingController();
    final procCtrl = TextEditingController();
    final iconCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add App'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'App name *'),
              ),
              TextField(
                controller: pathCtrl,
                decoration:
                    const InputDecoration(labelText: 'Executable path / Package name *'),
              ),
              TextField(
                controller: procCtrl,
                decoration: const InputDecoration(
                    labelText: 'Process name (optional, Windows/macOS)'),
              ),
              TextField(
                controller: iconCtrl,
                decoration: const InputDecoration(
                  labelText: 'Icon key (optional)',
                  hintText: 'chrome, steam, vscode…',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );

    if (confirmed == true &&
        nameCtrl.text.isNotEmpty &&
        pathCtrl.text.isNotEmpty) {
      await ref.read(apiServiceProvider).addLauncherApp(
            name: nameCtrl.text.trim(),
            executablePath: pathCtrl.text.trim(),
            processName: procCtrl.text.trim(),
            iconKey: iconCtrl.text.trim(),
          );
      await ref.read(appLauncherProvider.notifier).refresh();
    }
  }

  Future<void> _showManageSheet(List<LauncherAppInfo> apps) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ManageAppsSheet(
        apps: apps,
        onRemove: (id) async {
          await ref.read(apiServiceProvider).removeLauncherApp(id);
          await ref.read(appLauncherProvider.notifier).refresh();
        },
        onAdd: _showAddDialog,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = ref.watch(appLauncherProvider).when(
      loading: () => AppLauncherStatus.unavailable(),
      error: (_, __) => AppLauncherStatus.unavailable(),
      data: (s) => s,
    );
    final iconColor = widget.hasBg ? Colors.white70 : cs.primary;
    final labelColor = widget.hasBg ? Colors.white70 : cs.onSurfaceVariant;
    final subColor = widget.hasBg ? Colors.white54 : cs.outline;

    return Card(
      color: widget.hasBg ? Colors.black45 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.apps, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text('App Launcher',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: labelColor)),
              const Spacer(),
              if (status.available)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.settings_outlined,
                        size: 16, color: subColor),
                    tooltip: 'Manage apps',
                    onPressed: () => _showManageSheet(status.apps),
                  ),
                ),
              if (widget.badge != null) ...[
                const SizedBox(width: 4),
                widget.badge!,
              ],
            ]),
            const SizedBox(height: 8),
            if (!status.available)
              Text(
                'App launcher not available on this server',
                style: TextStyle(fontSize: 12, color: subColor),
              )
            else if (status.apps.isEmpty)
              GestureDetector(
                onTap: _showAddDialog,
                child: Text(
                  'Tap  ⚙  to add apps',
                  style: TextStyle(
                      fontSize: 12,
                      color: subColor,
                      fontStyle: FontStyle.italic),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: status.apps
                    .map((app) => _AppIconButton(
                          app: app,
                          iconData: _iconFor(app.iconKey),
                          hasBg: widget.hasBg,
                          onTap: () async {
                            await ref
                                .read(apiServiceProvider)
                                .launchApp(app.id);
                          },
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Manage-apps bottom sheet ──────────────────────────────────────────────────

class _ManageAppsSheet extends StatelessWidget {
  const _ManageAppsSheet({
    required this.apps,
    required this.onRemove,
    required this.onAdd,
  });
  final List<LauncherAppInfo> apps;
  final Future<void> Function(String id) onRemove;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text('Manage Apps',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (apps.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No apps configured yet.',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: apps.length,
                  itemBuilder: (_, i) {
                    final app = apps[i];
                    return ListTile(
                      leading: Icon(_iconFor(app.iconKey),
                          color: cs.primary, size: 24),
                      title: Text(app.name),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        tooltip: 'Remove',
                        onPressed: () async {
                          await onRemove(app.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.add_circle_outline, color: cs.primary),
              title: const Text('Add app'),
              onTap: () async {
                Navigator.pop(context);
                await onAdd();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── App icon button ───────────────────────────────────────────────────────────

class _AppIconButton extends StatelessWidget {
  const _AppIconButton({
    required this.app,
    required this.iconData,
    required this.hasBg,
    required this.onTap,
  });
  final LauncherAppInfo app;
  final IconData iconData;
  final bool hasBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasBg
                        ? Colors.white.withValues(alpha: 0.15)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(iconData,
                        size: 28,
                        color: hasBg ? Colors.white70 : cs.primary),
                  ),
                ),
                if (app.running)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              app.name,
              style: TextStyle(
                  fontSize: 10,
                  color: hasBg ? Colors.white70 : cs.onSurface),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
