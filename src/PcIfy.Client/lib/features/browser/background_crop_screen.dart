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
  final _transformController = TransformationController();
  bool _showGrid = true;

  void _reset() => _transformController.value = Matrix4.identity();

  void _save() {
    final m = _transformController.value;
    final scale = m.getMaxScaleOnAxis();
    final dx = m.entry(0, 3);
    final dy = m.entry(1, 3);
    final hasCrop = (scale - 1.0).abs() > 0.001 || dx.abs() > 0.5 || dy.abs() > 0.5;
    context.pop(BackgroundCropResult(
      imagePath: widget.imagePath,
      cropOffsetDx: hasCrop ? dx : null,
      cropOffsetDy: hasCrop ? dy : null,
      cropScale: hasCrop ? scale : null,
    ));
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
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
            icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off),
            tooltip: 'Toggle grid',
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            transformationController: _transformController,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.1,
            maxScale: 8.0,
            child: CachedNetworkImage(
              imageUrl: widget.imageUri,
              fit: BoxFit.contain,
              width: mq.size.width,
              height: mq.size.height,
              placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.broken_image, color: Colors.white54, size: 64),
            ),
          ),
          if (_showGrid)
            const IgnorePointer(
              child: CustomPaint(painter: _GridOverlayPainter()),
            ),
          Positioned(
            bottom: mq.padding.bottom + 16,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'Pinch to zoom · Drag to pan',
                style: TextStyle(
                    color: Colors.white60, fontSize: 12, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Grid overlay (rule-of-thirds, no crop handles) ─────────────────────────

class _GridOverlayPainter extends CustomPainter {
  const _GridOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    // Rule-of-thirds lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 0.8;
    for (var i = 1; i <= 2; i++) {
      final x = w * i / 3;
      final y = h * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Dashed screen-edge border (= crop frame)
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    _drawDashedRect(canvas, rect.deflate(1), borderPaint);
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dashLen = 12.0;
    const gapLen = 6.0;
    final path = Path()..addRect(rect);
    final metric = path.computeMetrics().first;
    var dist = 0.0;
    var drawing = true;
    final dashes = Path();
    while (dist < metric.length) {
      final segLen = drawing ? dashLen : gapLen;
      if (drawing) {
        dashes.addPath(
          metric.extractPath(dist, math.min(dist + segLen, metric.length)),
          Offset.zero,
        );
      }
      dist += segLen;
      drawing = !drawing;
    }
    canvas.drawPath(dashes, paint);
  }

  @override
  bool shouldRepaint(_GridOverlayPainter _) => false;
}
