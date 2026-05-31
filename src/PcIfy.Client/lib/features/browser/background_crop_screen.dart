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
    this.initialCropScale,
    this.initialCropOffsetDx,
    this.initialCropOffsetDy,
  });
  final String imageUri;
  final String imagePath;
  // Existing crop values — used to restore state when adjusting an already-set background.
  final double? initialCropScale;
  final double? initialCropOffsetDx;
  final double? initialCropOffsetDy;

  @override
  State<BackgroundCropScreen> createState() => _BackgroundCropScreenState();
}

class _BackgroundCropScreenState extends State<BackgroundCropScreen> {
  final _transformController = TransformationController();
  bool _showGrid = true;
  Size? _imageSize;
  Size? _screenSize;
  bool _transformInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  void _loadImageSize() {
    final provider = CachedNetworkImageProvider(widget.imageUri);
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      stream.removeListener(listener);
      if (!mounted) return;
      setState(() {
        _imageSize = Size(
            info.image.width.toDouble(), info.image.height.toDouble());
      });
      _maybeInitTransform();
    });
    stream.addListener(listener);
  }

  /// Called once when both image size and screen size are known.
  void _maybeInitTransform() {
    if (_transformInitialized) return;
    final imgSize = _imageSize;
    final screen = _screenSize;
    if (imgSize == null || screen == null) return;
    _transformInitialized = true;
    _applyBgCropToViewer(
      widget.initialCropScale ?? 1.0,
      widget.initialCropOffsetDx ?? 0.0,
      widget.initialCropOffsetDy ?? 0.0,
      screen,
      imgSize,
    );
  }

  /// Converts background-render crop values (s, dx, dy) to a viewer Matrix4
  /// that makes the contain-displayed image look identical to the background.
  void _applyBgCropToViewer(
      double bgS, double bgDx, double bgDy, Size screen, Size img) {
    final p = _coverParams(screen, img);
    final vScale = bgS * p.cvs / p.cs;
    final vDx = bgDx - vScale * p.coverX;
    final vDy = bgDy - vScale * p.coverY;
    _transformController.value = Matrix4.identity()
      ..setEntry(0, 0, vScale)
      ..setEntry(1, 1, vScale)
      ..setEntry(0, 3, vDx)
      ..setEntry(1, 3, vDy);
  }

  void _reset() {
    final imgSize = _imageSize;
    final screen = _screenSize;
    if (imgSize != null && screen != null) {
      // Reset to default cover (no extra crop)
      _applyBgCropToViewer(1.0, 0.0, 0.0, screen, imgSize);
    } else {
      _transformController.value = Matrix4.identity();
    }
  }

  void _save() {
    final m = _transformController.value;
    final imgSize = _imageSize;
    final screen = _screenSize;

    if (imgSize == null || screen == null) {
      context.pop(BackgroundCropResult(imagePath: widget.imagePath));
      return;
    }

    final vScale = m.getMaxScaleOnAxis();
    final vDx = m.entry(0, 3);
    final vDy = m.entry(1, 3);

    final p = _coverParams(screen, imgSize);
    final bgS = vScale * p.cs / p.cvs;
    final bgDx = vDx + vScale * p.coverX;
    final bgDy = vDy + vScale * p.coverY;

    // If essentially the same as default cover, save without crop data
    final hasCrop =
        (bgS - 1.0).abs() > 0.01 || bgDx.abs() > 1.0 || bgDy.abs() > 1.0;

    context.pop(BackgroundCropResult(
      imagePath: widget.imagePath,
      cropOffsetDx: hasCrop ? bgDx : null,
      cropOffsetDy: hasCrop ? bgDy : null,
      cropScale: hasCrop ? bgS : null,
    ));
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  // ── Coordinate helpers ──────────────────────────────────────────────────────

  ({double cs, double cvs, double cx, double cy, double coverX, double coverY})
      _coverParams(Size screen, Size img) {
    // cs  = contain scale  (min → fits fully within screen)
    // cvs = cover scale    (max → fills screen, may crop)
    final cs =
        math.min(screen.width / img.width, screen.height / img.height);
    final cvs =
        math.max(screen.width / img.width, screen.height / img.height);
    final cx = (screen.width - img.width * cs) / 2;
    final cy = (screen.height - img.height * cs) / 2;
    // coverX/Y = top-left of the "cover zone" rectangle inside the contain display
    final coverX = cx + (img.width * cs - screen.width * cs / cvs) / 2;
    final coverY = cy + (img.height * cs - screen.height * cs / cvs) / 2;
    return (cs: cs, cvs: cvs, cx: cx, cy: cy, coverX: coverX, coverY: coverY);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

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
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = constraints.biggest;

          // Capture screen size and trigger transform init on first layout
          if (_screenSize != screenSize) {
            _screenSize = screenSize;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _maybeInitTransform());
          }

          return Stack(
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
                  width: screenSize.width,
                  height: screenSize.height,
                  placeholder: (_, __) => const Center(
                      child:
                          CircularProgressIndicator(color: Colors.white)),
                  errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64),
                ),
              ),
              // Crop-zone overlay: dims the parts of the image outside the
              // current crop (the area that won't appear as background).
              if (_imageSize != null)
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _transformController,
                    builder: (context, _) {
                      final m = _transformController.value;
                      final vScale = m.getMaxScaleOnAxis();
                      final vDx = m.entry(0, 3);
                      final vDy = m.entry(1, 3);
                      final p = _coverParams(screenSize, _imageSize!);
                      // Image bounding rect in screen space
                      final imgRect = Rect.fromLTWH(
                        vScale * p.cx + vDx,
                        vScale * p.cy + vDy,
                        _imageSize!.width * p.cs * vScale,
                        _imageSize!.height * p.cs * vScale,
                      );
                      // Crop zone in screen space = the screen itself
                      final cropZone = Offset.zero & screenSize;
                      return CustomPaint(
                        painter: _CropOverlayPainter(
                          imageRect: imgRect,
                          cropZone: cropZone,
                          showGrid: _showGrid,
                        ),
                      );
                    },
                  ),
                ),
              Positioned(
                bottom: mq.padding.bottom + 16,
                left: 0,
                right: 0,
                child: const Center(
                  child: Text(
                    'Zoom out to see full image · What fills the screen = background',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Overlay painter ─────────────────────────────────────────────────────────
//
// Draws:
//  • A semi-transparent dim over the parts of the IMAGE that fall outside the
//    crop zone (they won't appear in the background).
//  • A dashed border at the crop-zone boundary.
//  • An optional rule-of-thirds grid.

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({
    required this.imageRect,
    required this.cropZone,
    required this.showGrid,
  });
  final Rect imageRect;
  final Rect cropZone;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    // Dim the image area that falls outside the crop zone
    final outside = imageRect.intersect(cropZone);
    if (outside.isEmpty) {
      // Image is fully outside the screen — dim the whole image
      canvas.drawRect(
          imageRect,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.55)
            ..style = PaintingStyle.fill);
    } else {
      // Dim the parts of the imageRect that are outside cropZone
      final dimPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill;
      final dimPath = Path()
        ..addRect(imageRect)
        ..addRect(outside)
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(dimPath, dimPaint);
    }

    if (showGrid) {
      // Rule-of-thirds grid inside the crop zone
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..strokeWidth = 0.8;
      for (var i = 1; i <= 2; i++) {
        final x = cropZone.left + cropZone.width * i / 3;
        final y = cropZone.top + cropZone.height * i / 3;
        canvas.drawLine(
            Offset(x, cropZone.top), Offset(x, cropZone.bottom), gridPaint);
        canvas.drawLine(
            Offset(cropZone.left, y), Offset(cropZone.right, y), gridPaint);
      }
    }

    // Dashed border at crop zone edges
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    _drawDashedRect(canvas, cropZone.deflate(1), borderPaint);
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
          metric.extractPath(
              dist, math.min(dist + segLen, metric.length)),
          Offset.zero,
        );
      }
      dist += segLen;
      drawing = !drawing;
    }
    canvas.drawPath(dashes, paint);
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) =>
      old.imageRect != imageRect ||
      old.cropZone != cropZone ||
      old.showGrid != showGrid;
}
