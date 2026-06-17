import 'dart:async';
import 'dart:math' show max;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../services/api_service.dart';

// ─── Shared helpers ───────────────────────────────────────────────────────────

/// Evenly-spaced fractions across the video (avoids start/end).
List<double> _buildFractions(int count) =>
    List.generate(count, (i) => (i + 1) / (count + 1));

String _formatTimestamp(int posMs) {
  final d = Duration(milliseconds: posMs);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Per-thumbnail width: fills the available space naturally for small [count]
/// values, but enforces a minimum of 80 px so the strip scrolls horizontally
/// when [count] is large or the screen is narrow.
double _thumbWidth(BuildContext context, int count) {
  final available = MediaQuery.sizeOf(context).width - 16;
  return max(80.0, available / count);
}

// ─── VideoTimelineStrip ───────────────────────────────────────────────────────

/// Horizontal strip of [count] video thumbnails at evenly-spaced positions.
/// Scrolls horizontally when thumbnails cannot fit the screen width.
/// Tapping one calls [onSeekTap] with the position in milliseconds.
class VideoTimelineStrip extends StatefulWidget {
  const VideoTimelineStrip({
    super.key,
    required this.serverPath,
    required this.durationMs,
    required this.api,
    required this.quality,
    this.count = 5,
    this.height = 100,
    this.onSeekTap,
  });

  final String serverPath;
  final int durationMs;
  final ApiService api;
  final int quality;
  final int count;
  final double height;
  final void Function(int positionMs)? onSeekTap;

  @override
  State<VideoTimelineStrip> createState() => _VideoTimelineStripState();
}

class _VideoTimelineStripState extends State<VideoTimelineStrip> {
  List<String?>? _uris;
  List<double> _fracs = [];

  @override
  void initState() {
    super.initState();
    _fracs = _buildFractions(widget.count);
    _buildUris();
  }

  @override
  void didUpdateWidget(VideoTimelineStrip old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count ||
        old.durationMs != widget.durationMs ||
        old.serverPath != widget.serverPath) {
      _fracs = _buildFractions(widget.count);
      setState(() => _uris = null);
      _buildUris();
    }
  }

  Future<void> _buildUris() async {
    final fracs = _fracs;
    final uris = <String?>[];
    for (final frac in fracs) {
      final posMs = (widget.durationMs * frac).round();
      final uri = await widget.api.buildThumbnailUriWithToken(
        widget.serverPath,
        quality: widget.quality,
        atSeconds: posMs / 1000.0,
      );
      uris.add(uri);
    }
    if (mounted && fracs == _fracs) setState(() => _uris = uris);
  }

  @override
  Widget build(BuildContext context) {
    final itemWidth = _thumbWidth(context, widget.count);
    return SizedBox(
      height: widget.height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_fracs.length, (i) {
            final posMs = (widget.durationMs * _fracs[i]).round();
            final uri = _uris?[i];
            return SizedBox(
              width: itemWidth,
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
                        _formatTimestamp(posMs),
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
      ),
    );
  }
}

// ─── VideoPlayerTimelineStrip ─────────────────────────────────────────────────

/// Timeline strip wired directly to a [Player] for use inside the gallery
/// and split-view video players. Derives server path from the stream URI
/// and calls [player.seek] on thumbnail tap.
///
/// [onInteract] is called before each seek so callers can reset auto-hide timers.
class VideoPlayerTimelineStrip extends StatefulWidget {
  const VideoPlayerTimelineStrip({
    super.key,
    required this.player,
    required this.durationMs,
    required this.filePath,
    required this.api,
    required this.quality,
    this.count = 5,
    this.height = 88,
    this.onInteract,
  });

  final Player player;
  final int durationMs;
  /// Stream URI — used to derive the server path for thumbnail requests.
  final String filePath;
  final ApiService api;
  final int quality;
  final int count;
  final double height;
  final VoidCallback? onInteract;

  @override
  State<VideoPlayerTimelineStrip> createState() =>
      _VideoPlayerTimelineStripState();
}

class _VideoPlayerTimelineStripState extends State<VideoPlayerTimelineStrip> {
  List<String?>? _uris;
  List<double> _fracs = [];

  @override
  void initState() {
    super.initState();
    _fracs = _buildFractions(widget.count);
    _buildUris();
  }

  @override
  void didUpdateWidget(VideoPlayerTimelineStrip old) {
    super.didUpdateWidget(old);
    if (old.filePath != widget.filePath ||
        old.durationMs != widget.durationMs ||
        old.count != widget.count) {
      _fracs = _buildFractions(widget.count);
      setState(() => _uris = null);
      _buildUris();
    }
  }

  String? _serverPathFromStreamUri(String streamUri) {
    try {
      final uri = Uri.parse(streamUri);
      const prefix = '/api/files/stream/';
      if (uri.path.startsWith(prefix)) {
        return Uri.decodeComponent(uri.path.substring(prefix.length));
      }
    } catch (_) {}
    return null;
  }

  Future<void> _buildUris() async {
    final serverPath = _serverPathFromStreamUri(widget.filePath);
    if (serverPath == null) return;
    final fracs = _fracs;
    final uris = <String?>[];
    for (final frac in fracs) {
      final posMs = (widget.durationMs * frac).round();
      final uri = await widget.api.buildThumbnailUriWithToken(
        serverPath,
        quality: widget.quality,
        atSeconds: posMs / 1000.0,
      );
      uris.add(uri);
    }
    if (mounted && fracs == _fracs) setState(() => _uris = uris);
  }

  @override
  Widget build(BuildContext context) {
    final itemWidth = _thumbWidth(context, widget.count);
    return SizedBox(
      height: widget.height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_fracs.length, (i) {
            final posMs = (widget.durationMs * _fracs[i]).round();
            final uri = _uris?[i];
            return SizedBox(
              width: itemWidth,
              child: GestureDetector(
                onTap: () {
                  widget.onInteract?.call();
                  widget.player.seek(Duration(milliseconds: posMs));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: _uris == null
                              ? Container(color: Colors.white12)
                              : uri != null
                                  ? CachedNetworkImage(
                                      imageUrl: uri,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      placeholder: (_, __) =>
                                          Container(color: Colors.white12),
                                      errorWidget: (_, __, ___) => Container(
                                        color: Colors.white12,
                                        child: const Icon(
                                            Icons.videocam_off_outlined,
                                            color: Colors.white38,
                                            size: 18),
                                      ),
                                    )
                                  : Container(color: Colors.white12),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatTimestamp(posMs),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 9),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Placeholders ─────────────────────────────────────────────────────────────

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

/// Loading placeholder — [count] grey boxes, same layout as the strip.
class VideoTimelinePlaceholder extends StatelessWidget {
  const VideoTimelinePlaceholder({super.key, this.count = 5, this.height = 100});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    final itemWidth = _thumbWidth(context, count);
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            count,
            (_) => SizedBox(
              width: itemWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
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
      ),
    );
  }
}
