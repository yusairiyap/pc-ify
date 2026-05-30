import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BackgroundCropResult {
  const BackgroundCropResult({
    required this.imagePath,
    this.cropOffsetDx,
    this.cropOffsetDy,
    this.cropScale,
  });
  final String imagePath;
  final double? cropOffsetDx;
  final double? cropOffsetDy;
  final double? cropScale;
}

class BackgroundCropScreen extends StatefulWidget {
  const BackgroundCropScreen({
    super.key,
    required this.imageUri,
    required this.imagePath,
  });
  final String imageUri;
  final String imagePath;

  @override
  State<BackgroundCropScreen> createState() => _BackgroundCropScreenState();
}

class _BackgroundCropScreenState extends State<BackgroundCropScreen> {
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  // Gesture tracking
  double? _initialScale;
  Offset? _initialFocalPoint;
  Offset? _initialOffset;

  void _onScaleStart(ScaleStartDetails d) {
    _initialScale = _scale;
    _initialFocalPoint = d.localFocalPoint;
    _initialOffset = _offset;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final newScale = (_initialScale! * d.scale).clamp(1.0, 8.0);
    // Keep the focal point fixed on the image while panning / zooming
    final ratio = newScale / _initialScale!;
    final newOffset = d.localFocalPoint + (_initialOffset! - _initialFocalPoint!) * ratio;
    setState(() {
      _scale = newScale;
      _offset = newOffset;
    });
  }

  void _reset() => setState(() {
        _scale = 1.0;
        _offset = Offset.zero;
      });

  void _save() {
    final hasCrop = _scale != 1.0 || _offset != Offset.zero;
    context.pop(BackgroundCropResult(
      imagePath: widget.imagePath,
      cropOffsetDx: hasCrop ? _offset.dx : null,
      cropOffsetDy: hasCrop ? _offset.dy : null,
      cropScale: hasCrop ? _scale : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        title: const Text('Set Background'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset',
            onPressed: _reset,
          ),
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image — BoxFit.cover base, transform applied on top
              ClipRect(
                child: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(0, 0, _scale)
                    ..setEntry(1, 1, _scale)
                    ..setEntry(0, 3, _offset.dx)
                    ..setEntry(1, 3, _offset.dy),
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUri,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(color: Colors.white)),
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 64),
                  ),
                ),
              ),
              // Crop overlay: dashed border, rule-of-thirds, handles
              const IgnorePointer(
                child: CustomPaint(
                  painter: _CropOverlayPainter(),
                ),
              ),
              // Bottom hint
              Positioned(
                bottom: mq.padding.bottom + 16,
                left: 0,
                right: 0,
                child: const Center(
                  child: Text(
                    'Pinch to zoom · Drag to pan',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Crop overlay painter ────────────────────────────────────────────────────

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const padding = 0.0; // crop rect fills the screen edge-to-edge
    final rect = Rect.fromLTWH(padding, padding, w - padding * 2, h - padding * 2);

    // ── Rule-of-thirds grid ──────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 0.8;
    final thirdX1 = rect.left + rect.width / 3;
    final thirdX2 = rect.left + rect.width * 2 / 3;
    final thirdY1 = rect.top + rect.height / 3;
    final thirdY2 = rect.top + rect.height * 2 / 3;
    canvas.drawLine(Offset(thirdX1, rect.top), Offset(thirdX1, rect.bottom), gridPaint);
    canvas.drawLine(Offset(thirdX2, rect.top), Offset(thirdX2, rect.bottom), gridPaint);
    canvas.drawLine(Offset(rect.left, thirdY1), Offset(rect.right, thirdY1), gridPaint);
    canvas.drawLine(Offset(rect.left, thirdY2), Offset(rect.right, thirdY2), gridPaint);

    // ── Dashed border ────────────────────────────────────────────────────────
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    _drawDashedRect(canvas, rect, borderPaint, dashLen: 12, gapLen: 6);

    // ── Corner handles ───────────────────────────────────────────────────────
    final handlePaint = Paint()..color = Colors.white;
    const hr = 7.0; // handle radius
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];
    for (final c in corners) {
      canvas.drawCircle(c, hr, handlePaint);
      canvas.drawCircle(c, hr, Paint()..color = Colors.black38..style = PaintingStyle.stroke..strokeWidth = 1);
    }

    // ── Edge mid-point handles ───────────────────────────────────────────────
    const er = 5.0;
    final edges = [
      Offset(rect.center.dx, rect.top),
      Offset(rect.center.dx, rect.bottom),
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
    ];
    for (final e in edges) {
      canvas.drawCircle(e, er, handlePaint);
      canvas.drawCircle(e, er, Paint()..color = Colors.black38..style = PaintingStyle.stroke..strokeWidth = 1);
    }
  }

  void _drawDashedRect(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    required double dashLen,
    required double gapLen,
  }) {
    final path = Path()..addRect(rect);
    final metric = path.computeMetrics().first;
    final total = metric.length;
    var dist = 0.0;
    bool drawing = true;
    final dashes = Path();
    while (dist < total) {
      final segLen = drawing ? dashLen : gapLen;
      if (drawing) {
        dashes.addPath(
          metric.extractPath(dist, math.min(dist + segLen, total)),
          Offset.zero,
        );
      }
      dist += segLen;
      drawing = !drawing;
    }
    canvas.drawPath(dashes, paint);
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) => false;
}
