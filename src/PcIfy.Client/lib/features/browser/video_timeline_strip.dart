import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';

const _fractions = [0.15, 0.30, 0.45, 0.60, 0.75];

/// Horizontal strip of 5 video thumbnails at 15 / 30 / 45 / 60 / 75 % of
/// [durationMs]. Tapping one calls [onSeekTap] with the position in ms.
class VideoTimelineStrip extends StatefulWidget {
  const VideoTimelineStrip({
    super.key,
    required this.serverPath,
    required this.durationMs,
    required this.api,
    required this.quality,
    this.onSeekTap,
  });

  final String serverPath;
  final int durationMs;
  final ApiService api;
  final int quality;
  final void Function(int positionMs)? onSeekTap;

  @override
  State<VideoTimelineStrip> createState() => _VideoTimelineStripState();
}

class _VideoTimelineStripState extends State<VideoTimelineStrip> {
  List<String?>? _uris;

  @override
  void initState() {
    super.initState();
    _buildUris();
  }

  Future<void> _buildUris() async {
    final uris = <String?>[];
    for (final frac in _fractions) {
      final posMs = (widget.durationMs * frac).round();
      final atSec = posMs / 1000.0;
      final uri = await widget.api.buildThumbnailUriWithToken(
        widget.serverPath,
        quality: widget.quality,
        atSeconds: atSec,
      );
      uris.add(uri);
    }
    if (mounted) setState(() => _uris = uris);
  }

  String _ts(int posMs) {
    final d = Duration(milliseconds: posMs);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Row(
        children: List.generate(_fractions.length, (i) {
          final posMs = (widget.durationMs * _fractions[i]).round();
          final uri = _uris?[i];
          return Expanded(
            child: GestureDetector(
              onTap: widget.onSeekTap != null
                  ? () => widget.onSeekTap!(posMs)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _uris == null
                            ? const _ShimmerBox()
                            : uri != null
                                ? CachedNetworkImage(
                                    imageUrl: uri,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (_, __) =>
                                        const _ShimmerBox(),
                                    errorWidget: (_, __, ___) =>
                                        const _VideoPlaceholder(),
                                  )
                                : const _VideoPlaceholder(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _ts(posMs),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Shown while thumbnail URIs are being built (async token fetch).
class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// Shown when thumbnails are unavailable (e.g. Android server stub).
class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Icon(Icons.videocam_off_outlined, size: 24),
      ),
    );
  }
}

/// Loading placeholder — 5 grey boxes, same layout as the strip.
class VideoTimelinePlaceholder extends StatelessWidget {
  const VideoTimelinePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Row(
        children: List.generate(
          5,
          (_) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: const _ShimmerBox(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 8,
                    width: 30,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
