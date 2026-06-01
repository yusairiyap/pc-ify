import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class BackgroundVideoTrimResult {
  const BackgroundVideoTrimResult({
    required this.videoPath,
    this.loopStartMs,
    this.loopEndMs,
  });
  final String videoPath;
  final int? loopStartMs;
  final int? loopEndMs;
}

class BackgroundVideoTrimScreen extends StatefulWidget {
  const BackgroundVideoTrimScreen({
    super.key,
    required this.videoUri,
    required this.videoPath,
    this.initialStartMs,
    this.initialEndMs,
  });
  final String videoUri;
  final String videoPath;
  final int? initialStartMs;
  final int? initialEndMs;

  @override
  State<BackgroundVideoTrimScreen> createState() =>
      _BackgroundVideoTrimScreenState();
}

class _BackgroundVideoTrimScreenState
    extends State<BackgroundVideoTrimScreen> {
  late final Player _player;
  late final VideoController _controller;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Normalised 0..1 values for the handles
  double _startFrac = 0.0;
  double _endFrac = 1.0;

  bool _ready = false;
  bool _seeking = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    _player.setVolume(0);

    _player.stream.duration.listen((d) {
      if (!mounted) return;
      setState(() {
        _duration = d;
        if (d.inMilliseconds > 0) {
          _startFrac = widget.initialStartMs != null
              ? (widget.initialStartMs! / d.inMilliseconds).clamp(0.0, 1.0)
              : 0.0;
          _endFrac = widget.initialEndMs != null
              ? (widget.initialEndMs! / d.inMilliseconds).clamp(0.0, 1.0)
              : 1.0;
          _ready = true;
        }
      });
    });

    // On the very first position event, seek to the previous trim start so
    // the user sees where they left off. Using a flag so it only fires once.
    bool didInitialSeek = false;
    _player.stream.position.listen((p) {
      if (!mounted || _seeking) return;
      setState(() => _position = p);

      if (!didInitialSeek) {
        didInitialSeek = true;
        final seekMs = widget.initialStartMs ?? 0;
        if (seekMs > 0) {
          _seeking = true;
          _player.seek(Duration(milliseconds: seekMs))
              .then((_) => _seeking = false);
          return;
        }
      }

      _enforceLoop(p);
    });

    _player.open(Media(widget.videoUri));
    _player.setPlaylistMode(PlaylistMode.loop);
  }

  void _enforceLoop(Duration position) {
    if (_duration.inMilliseconds == 0) return;
    final endMs = (_endFrac * _duration.inMilliseconds).round();
    final startMs = (_startFrac * _duration.inMilliseconds).round();
    if (endMs > 0 && position.inMilliseconds >= endMs) {
      _player.seek(Duration(milliseconds: startMs));
    }
  }

  void _reset() {
    setState(() {
      _startFrac = 0.0;
      _endFrac = 1.0;
    });
    _player.seek(Duration.zero);
  }

  void _save() {
    final totalMs = _duration.inMilliseconds;
    final startMs = (_startFrac * totalMs).round();
    final endMs = (_endFrac * totalMs).round();
    final hasLoop = totalMs > 0 &&
        (startMs > 0 || endMs < totalMs);
    context.pop(BackgroundVideoTrimResult(
      videoPath: widget.videoPath,
      loopStartMs: hasLoop ? startMs : null,
      loopEndMs: hasLoop ? endMs : null,
    ));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatMs(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs =
        (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$cs';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final totalMs = _duration.inMilliseconds;
    final startMs = totalMs > 0 ? (_startFrac * totalMs).round() : 0;
    final endMs = totalMs > 0 ? (_endFrac * totalMs).round() : 0;
    final posFrac = totalMs > 0
        ? (_position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: const Text('Set Video Loop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset',
            onPressed: _reset,
          ),
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Video(
            controller: _controller,
            fit: BoxFit.cover,
            controls: NoVideoControls,
          ),
          // Timeline overlay raised above system gesture zone
          Positioned(
            left: 0,
            right: 0,
            bottom: mq.viewPadding.bottom,
            child: _TimelineBar(
              startFrac: _startFrac,
              endFrac: _endFrac,
              posFrac: posFrac.toDouble(),
              startLabel: _formatMs(startMs),
              endLabel: _formatMs(endMs),
              ready: _ready,
              horizontalPadding: 20,
              onStartChanged: (v) {
                setState(() => _startFrac = v.clamp(0.0, _endFrac - 0.01));
                _seeking = true;
                _player
                    .seek(Duration(
                        milliseconds:
                            (_startFrac * totalMs).round()))
                    .then((_) => _seeking = false);
              },
              onEndChanged: (v) {
                setState(() => _endFrac = v.clamp(_startFrac + 0.01, 1.0));
              },
            ),
          ),
          Positioned(
            bottom: mq.viewPadding.bottom + 96,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'Drag handles to set loop range',
                style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline bar ─────────────────────────────────────────────────────────────

class _TimelineBar extends StatelessWidget {
  const _TimelineBar({
    required this.startFrac,
    required this.endFrac,
    required this.posFrac,
    required this.startLabel,
    required this.endLabel,
    required this.ready,
    required this.onStartChanged,
    required this.onEndChanged,
    this.horizontalPadding = 0,
  });

  final double startFrac;
  final double endFrac;
  final double posFrac;
  final String startLabel;
  final String endLabel;
  final bool ready;
  final double horizontalPadding;
  final ValueChanged<double> onStartChanged;
  final ValueChanged<double> onEndChanged;

  static const _barHeight = 56.0;
  static const _labelHeight = 20.0;
  static const _handleWidth = 18.0;
  static const _totalHeight = _barHeight + _labelHeight;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      height: _totalHeight,
      color: Colors.black87,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Stack(
          children: [
            // Film-strip background
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _barHeight,
              child: _FilmStripPainterWidget(),
            ),
            // Selection highlight
            if (ready)
              LayoutBuilder(builder: (context, constraints) {
                final w = constraints.maxWidth;
                final left = startFrac * w;
                final width = (endFrac - startFrac) * w;
                return Stack(children: [
                  // Dimmed regions outside selection
                  Positioned(
                    top: 0,
                    left: 0,
                    width: left,
                    height: _barHeight,
                    child: Container(color: Colors.black.withValues(alpha: 0.55)),
                  ),
                  Positioned(
                    top: 0,
                    left: left + width,
                    right: 0,
                    height: _barHeight,
                    child: Container(color: Colors.black.withValues(alpha: 0.55)),
                  ),
                  // Selection band
                  Positioned(
                    top: 0,
                    left: left,
                    width: width,
                    height: _barHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(color: accent, width: 2),
                        ),
                        color: accent.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  // Start handle
                  Positioned(
                    top: 0,
                    left: (left - _handleWidth / 2).clamp(0, w - _handleWidth),
                    width: _handleWidth,
                    height: _barHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (d) =>
                          onStartChanged(startFrac + d.delta.dx / w),
                      child: _Handle(color: accent, isLeft: true),
                    ),
                  ),
                  // End handle
                  Positioned(
                    top: 0,
                    left: (left + width - _handleWidth / 2)
                        .clamp(0, w - _handleWidth),
                    width: _handleWidth,
                    height: _barHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (d) =>
                          onEndChanged(endFrac + d.delta.dx / w),
                      child: _Handle(color: accent, isLeft: false),
                    ),
                  ),
                  // Playback position line
                  Positioned(
                    top: 0,
                    left: (posFrac * w - 1).clamp(0, w - 1),
                    width: 2,
                    height: _barHeight,
                    child: Container(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  // Time labels
                  Positioned(
                    top: _barHeight,
                    left: 0,
                    right: 0,
                    height: _labelHeight,
                    child: Stack(children: [
                      Positioned(
                        left: (left - 20).clamp(0, w - 60),
                        child: Text(
                          startLabel,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                      ),
                      Positioned(
                        left: (left + width - 20).clamp(0, w - 60),
                        child: Text(
                          endLabel,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                      ),
                    ]),
                  ),
                ]);
              }),
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.color, required this.isLeft});
  final Color color;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? const Radius.circular(4) : Radius.zero,
          right: isLeft ? Radius.zero : const Radius.circular(4),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Container(
                width: 2,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Simple custom painter for a film-strip background pattern
class _FilmStripPainterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _FilmStripPainter(
        color: Color(0xFF1A1A1A),
        perfColor: Color(0xFF2A2A2A),
      ),
    );
  }
}

class _FilmStripPainter extends CustomPainter {
  const _FilmStripPainter({required this.color, required this.perfColor});
  final Color color;
  final Color perfColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = color);

    final perf = Paint()
      ..color = perfColor
      ..style = PaintingStyle.fill;

    const perfW = 10.0;
    const perfH = 8.0;
    const perfMargin = 3.0;
    const perfSpacing = 16.0;

    var x = perfSpacing / 2;
    while (x < size.width) {
      // Top row
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - perfW / 2, perfMargin, perfW, perfH),
          const Radius.circular(2),
        ),
        perf,
      );
      // Bottom row
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - perfW / 2, size.height - perfMargin - perfH,
              perfW, perfH),
          const Radius.circular(2),
        ),
        perf,
      );
      x += perfSpacing;
    }
  }

  @override
  bool shouldRepaint(_FilmStripPainter old) =>
      old.color != color || old.perfColor != perfColor;
}
