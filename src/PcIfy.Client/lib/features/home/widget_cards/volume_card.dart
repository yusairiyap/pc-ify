import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/services_providers.dart';

class VolumeCard extends ConsumerStatefulWidget {
  const VolumeCard({super.key, required this.hasBg});
  final bool hasBg;

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

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(controlStatusProvider);
    final cs = Theme.of(context).colorScheme;

    final (level, muted, available) = statusAsync.when(
      loading: () => (50, false, false),
      error: (_, __) => (50, false, false),
      data: (s) => (s.volume.level, s.volume.muted, s.volume.available),
    );

    final displayLevel = _localLevel ?? level.toDouble();

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
                color: widget.hasBg ? Colors.white70 : cs.primary, size: 18,
              ),
              const SizedBox(width: 6),
              Text('Volume',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: widget.hasBg ? Colors.white70 : cs.onSurfaceVariant,
                  )),
              const Spacer(),
              if (available)
                Row(children: [
                  Text(muted ? 'Muted' : '${displayLevel.round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.hasBg ? Colors.white54 : cs.onSurfaceVariant,
                      )),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 32, height: 32,
                    child: IconButton(
                      icon: Icon(muted ? Icons.volume_off : Icons.volume_up, size: 18),
                      padding: EdgeInsets.zero,
                      color: widget.hasBg ? Colors.white70 : cs.primary,
                      onPressed: () async {
                        await ref.read(apiServiceProvider).setMute(!muted);
                        ref.invalidate(controlStatusProvider);
                      },
                    ),
                  ),
                ]),
            ]),
            if (!available)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Not available',
                    style: TextStyle(
                      color: widget.hasBg ? Colors.white38 : cs.outline,
                      fontSize: 12,
                    )),
              )
            else
              Slider(
                value: displayLevel,
                min: 0, max: 100,
                divisions: 20,
                activeColor: widget.hasBg ? Colors.white70 : null,
                inactiveColor: widget.hasBg ? Colors.white24 : null,
                onChanged: (v) {
                  setState(() => _localLevel = v);
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () async {
                    await ref.read(apiServiceProvider).setVolume(v.round());
                    ref.invalidate(controlStatusProvider);
                    if (mounted) setState(() => _localLevel = null);
                  });
                },
                onChangeEnd: (v) async {
                  _debounce?.cancel();
                  await ref.read(apiServiceProvider).setVolume(v.round());
                  ref.invalidate(controlStatusProvider);
                  if (mounted) setState(() => _localLevel = null);
                },
              ),
          ],
        ),
      ),
    );
  }
}
