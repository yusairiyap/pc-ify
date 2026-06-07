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
  bool _editMode = false;

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
                    const InputDecoration(labelText: 'Executable path *'),
              ),
              TextField(
                controller: procCtrl,
                decoration: const InputDecoration(
                    labelText: 'Process name (optional)'),
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
              if (_editMode)
                TextButton(
                  onPressed: () => setState(() => _editMode = false),
                  child:
                      const Text('Done', style: TextStyle(fontSize: 12)),
                ),
              if (widget.badge != null) widget.badge!,
            ]),
            const SizedBox(height: 8),
            if (!status.available)
              Text(
                'App launcher not available on this server',
                style: TextStyle(fontSize: 12, color: subColor),
              )
            else if (status.apps.isEmpty && !_editMode)
              GestureDetector(
                onLongPress: () => setState(() => _editMode = true),
                child: Text(
                  'Long-press to add apps',
                  style: TextStyle(
                      fontSize: 12,
                      color: subColor,
                      fontStyle: FontStyle.italic),
                ),
              )
            else
              GestureDetector(
                onLongPress: () =>
                    setState(() => _editMode = !_editMode),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...status.apps.map((app) => _AppIconButton(
                          app: app,
                          iconData: _iconFor(app.iconKey),
                          hasBg: widget.hasBg,
                          editMode: _editMode,
                          onTap: _editMode
                              ? null
                              : () async {
                                  await ref
                                      .read(apiServiceProvider)
                                      .launchApp(app.id);
                                },
                          onRemove: _editMode
                              ? () async {
                                  await ref
                                      .read(apiServiceProvider)
                                      .removeLauncherApp(app.id);
                                  await ref
                                      .read(appLauncherProvider.notifier)
                                      .refresh();
                                }
                              : null,
                        )),
                    if (_editMode)
                      _AddButton(
                        hasBg: widget.hasBg,
                        onTap: _showAddDialog,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppIconButton extends StatelessWidget {
  const _AppIconButton({
    required this.app,
    required this.iconData,
    required this.hasBg,
    required this.editMode,
    this.onTap,
    this.onRemove,
  });
  final LauncherAppInfo app;
  final IconData iconData;
  final bool hasBg;
  final bool editMode;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(iconData,
                            size: 28,
                            color: hasBg ? Colors.white70 : cs.primary),
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
        ),
        if (editMode && onRemove != null)
          Positioned(
            top: -4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                    color: cs.error, shape: BoxShape.circle),
                child: Icon(Icons.close, size: 11, color: cs.onError),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.hasBg, required this.onTap});
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hasBg ? Colors.white12 : cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasBg
                      ? Colors.white24
                      : cs.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(Icons.add,
                  size: 28,
                  color: hasBg ? Colors.white54 : cs.primary),
            ),
            const SizedBox(height: 4),
            Text('Add',
                style: TextStyle(
                    fontSize: 10,
                    color: hasBg ? Colors.white54 : cs.primary)),
          ],
        ),
      ),
    );
  }
}
