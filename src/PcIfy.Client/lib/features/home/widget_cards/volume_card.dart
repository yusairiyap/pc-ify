import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/dashboard_models.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/services_providers.dart';

class VolumeCard extends ConsumerStatefulWidget {
  const VolumeCard({super.key, required this.hasBg, required this.size, this.badge});
  final bool hasBg;
  final WidgetSize size;
  final Widget? badge;

  @override
  ConsumerState<VolumeCard> createState() => _VolumeCardState();
}

class _VolumeCardState extends ConsumerState<VolumeCard> {
  double? _localLevel;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _setVolume(double v) async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      await ref.read(apiServiceProvider).setVolume(v.round());
      if (!mounted) return;
      ref.invalidate(controlStatusProvider);
      setState(() => _localLevel = null);
    });
  }

  Future<void> _commitVolume(double v) async {
    _debounce?.cancel();
    await ref.read(apiServiceProvider).setVolume(v.round());
    if (!mounted) return;
    ref.invalidate(controlStatusProvider);
    setState(() => _localLevel = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (level, muted, available) = ref.watch(controlStatusProvider).when(
      loading: () => (50, false, false),
      error: (_, __) => (50, false, false),
      data: (s) => (s.volume.level, s.volume.muted, s.volume.available),
    );
    final displayLevel = _localLevel ?? level.toDouble();
    final iconColor = widget.hasBg ? Colors.white70 : cs.primary;
    final labelColor = widget.hasBg ? Colors.white70 : cs.onSurfaceVariant;
    final valueColor = widget.hasBg ? Colors.white : cs.onSurface;
    final subColor = widget.hasBg ? Colors.white54 : cs.outline;

    final muteButton = SizedBox(
      width: 32, height: 32,
      child: IconButton(
        icon: Icon(muted ? Icons.volume_off : Icons.volume_up, size: 18),
        padding: EdgeInsets.zero,
        color: iconColor,
        onPressed: () async {
          await ref.read(apiServiceProvider).setMute(!muted);
          ref.invalidate(controlStatusProvider);
        },
      ),
    );

    final slider = Slider(
      value: displayLevel,
      min: 0, max: 100, divisions: 20,
      activeColor: widget.hasBg ? Colors.white70 : null,
      inactiveColor: widget.hasBg ? Colors.white24 : null,
      onChanged: (v) {
        setState(() => _localLevel = v);
        _setVolume(v);
      },
      onChangeEnd: _commitVolume,
    );

    if (widget.size.isTall) {
      return Card(
        color: widget.hasBg ? Colors.black45 : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                  muted ? Icons.volume_off : (displayLevel == 0 ? Icons.volume_mute : Icons.volume_up_outlined),
                  color: iconColor, size: 18,
                ),
                const SizedBox(width: 6),
                Text('Volume', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
                const Spacer(),
                if (available) ...[muteButton, const SizedBox(width: 4)],
                if (widget.badge != null) widget.badge!,
              ]),
              const Spacer(),
              if (!available)
                Center(child: Text('—', style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: subColor)))
              else
                Center(
                  child: Text(
                    muted ? 'Muted' : '${displayLevel.round()}%',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: muted ? subColor : valueColor,
                    ),
                  ),
                ),
              const Spacer(),
              if (!available)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Not available', style: TextStyle(color: subColor, fontSize: 12)),
                )
              else
                slider,
            ],
          ),
        ),
      );
    }

    return Card(
      color: widget.hasBg ? Colors.black45 : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(
                muted ? Icons.volume_off : (displayLevel == 0 ? Icons.volume_mute : Icons.volume_up_outlined),
                color: iconColor, size: 18,
              ),
              const SizedBox(width: 6),
              Text('Volume', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
              const Spacer(),
              if (available) ...[
                Text(muted ? 'Muted' : '${displayLevel.round()}%',
                    style: TextStyle(fontSize: 12, color: subColor)),
                const SizedBox(width: 4),
                muteButton,
                const SizedBox(width: 4),
              ],
              if (widget.badge != null) widget.badge!,
            ]),
            if (!available)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Not available', style: TextStyle(color: subColor, fontSize: 12)),
              )
            else
              slider,
          ],
        ),
      ),
    );
  }
}
