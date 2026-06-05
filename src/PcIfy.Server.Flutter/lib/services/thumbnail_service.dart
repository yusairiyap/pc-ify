import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/constants/media_types.dart';
import '../core/utils/path_sanitizer.dart';
import '../services/ffmpeg_setup_service.dart';

enum ThumbnailSize { small, medium, large }

extension ThumbnailSizeExt on ThumbnailSize {
  int get pixels {
    switch (this) {
      case ThumbnailSize.small:
        return 128;
      case ThumbnailSize.medium:
        return 256;
      case ThumbnailSize.large:
        return 512;
    }
  }

  static ThumbnailSize fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'small':
        return ThumbnailSize.small;
      case 'large':
        return ThumbnailSize.large;
      default:
        return ThumbnailSize.medium;
    }
  }
}

class ThumbnailService {
  static const _cacheDir = 'pcify-thumbs';

  Future<String> get _cachePath async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, _cacheDir));
    await dir.create(recursive: true);
    return dir.path;
  }

  /// [quality] 10–100: controls output pixel dimensions and JPEG encoding quality.
  /// [atSeconds] optional timestamp for video frame extraction (defaults to 2 s).
  Future<Uint8List?> getOrCreate(
    String filePath,
    List<String> allowedRoots, {
    int quality = 50,
    double? atSeconds,
  }) async {
    final sanitized = PathSanitizer.sanitize(filePath, allowedRoots);
    if (sanitized == null) return null;

    final ext = p.extension(sanitized).replaceFirst('.', '').toLowerCase();
    if (!MediaTypes.isThumbnailable(ext)) return null;

    final maxDim = _qualityToMaxDim(quality);
    final jpegQuality = _qualityToJpeg(quality);
    final cacheKey = _cacheKey(sanitized, quality, atSeconds);
    final cacheFile = File(p.join(await _cachePath, '$cacheKey.jpg'));

    if (await cacheFile.exists()) {
      return cacheFile.readAsBytes();
    }

    Uint8List? result;
    if (MediaTypes.isImage(ext)) {
      result = await compute(
          _resizeImage, _ResizeParams(sanitized, maxDim, jpegQuality));
    } else if (MediaTypes.isVideo(ext)) {
      result = await _videoThumbnail(sanitized, maxDim, jpegQuality, atSeconds);
    }

    if (result != null) {
      await cacheFile.writeAsBytes(result);
    }
    return result;
  }

  static int _qualityToMaxDim(int quality) =>
      ((quality / 100) * 512).round().clamp(32, 512);

  static int _qualityToJpeg(int quality) =>
      (60 + quality * 0.35).round().clamp(60, 95);

  String _cacheKey(String path, int quality, double? atSeconds) {
    final t = atSeconds != null ? atSeconds.toStringAsFixed(2) : '2.00';
    final input = '$path:q$quality:t$t';
    return sha256.convert(utf8.encode(input)).toString();
  }

  Future<Uint8List?> _videoThumbnail(
      String videoPath, int maxDim, int jpegQuality, double? atSeconds) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return _videoThumbnailMobile(videoPath, maxDim, jpegQuality, atSeconds);
    }
    return _videoThumbnailDesktop(videoPath, maxDim, jpegQuality, atSeconds);
  }

  Future<Uint8List?> _videoThumbnailMobile(
      String videoPath, int maxDim, int jpegQuality, double? atSeconds) async {
    return PlatformThumbnailHelper.getVideoThumbnail(
        videoPath, maxDim, jpegQuality, atSeconds);
  }

  Future<Uint8List?> _videoThumbnailDesktop(
      String videoPath, int maxDim, int jpegQuality, double? atSeconds) async {
    final ffmpeg = FFmpegSetupService.ffmpegPath;
    if (ffmpeg == null) return null;

    final tmp = await getTemporaryDirectory();
    final outPath = p.join(
        tmp.path, 'pcify-vt-${DateTime.now().millisecondsSinceEpoch}.jpg');

    final seekSec = atSeconds ?? 2.0;

    try {
      final result = await Process.run(ffmpeg, [
        '-ss', seekSec.toStringAsFixed(2),
        '-i', videoPath,
        '-frames:v', '1',
        '-q:v', '2',
        '-y',
        outPath,
      ]);

      if (result.exitCode != 0) return null;
      final frameFile = File(outPath);
      if (!await frameFile.exists()) return null;

      final frameBytes = await frameFile.readAsBytes();
      await frameFile.delete();
      return compute(
          _resizeImage, _ResizeParams.fromBytes(frameBytes, maxDim, jpegQuality));
    } catch (_) {
      return null;
    }
  }

  /// Get video duration in milliseconds. Returns null if unavailable.
  Future<int?> getVideoDurationMs(
      String filePath, List<String> allowedRoots) async {
    final sanitized = PathSanitizer.sanitize(filePath, allowedRoots);
    if (sanitized == null) return null;

    if (Platform.isAndroid || Platform.isIOS) {
      return PlatformVideoInfoHelper.getVideoDurationMs(sanitized);
    }
    return _getVideoDurationDesktop(sanitized);
  }

  Future<int?> _getVideoDurationDesktop(String videoPath) async {
    final ffmpeg = FFmpegSetupService.ffmpegPath;
    if (ffmpeg == null) return null;
    try {
      // ffmpeg -i file exits with error but prints format info to stderr
      final result = await Process.run(ffmpeg, ['-i', videoPath]);
      final output = result.stderr as String;
      final match =
          RegExp(r'Duration: (\d+):(\d+):(\d+\.?\d*)').firstMatch(output);
      if (match != null) {
        final h = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        final s = double.parse(match.group(3)!);
        return ((h * 3600 + m * 60 + s) * 1000).round();
      }
    } catch (_) {}
    return null;
  }
}

// ── Isolate-safe helpers ──────────────────────────────────────────────────────

class _ResizeParams {
  final String? path;
  final Uint8List? bytes;
  final int maxDim;
  final int jpegQuality;

  const _ResizeParams(this.path, this.maxDim, this.jpegQuality) : bytes = null;
  const _ResizeParams.fromBytes(this.bytes, this.maxDim, this.jpegQuality)
      : path = null;
}

Uint8List? _resizeImage(_ResizeParams params) {
  final bytes = params.bytes ?? File(params.path!).readAsBytesSync();
  final src = img.decodeImage(bytes);
  if (src == null) return null;

  final thumb = img.copyResize(
    src,
    width: src.width > src.height ? params.maxDim : -1,
    height: src.height >= src.width ? params.maxDim : -1,
    interpolation: img.Interpolation.linear,
  );
  return Uint8List.fromList(img.encodeJpg(thumb, quality: params.jpegQuality));
}

/// Indirection so ThumbnailService doesn't import video_thumbnail directly.
abstract class PlatformThumbnailHelper {
  static Future<Uint8List?> Function(String, int, int, double?)? _impl;

  static void register(
      Future<Uint8List?> Function(String, int, int, double?) impl) {
    _impl = impl;
  }

  static Future<Uint8List?> getVideoThumbnail(
      String path, int maxDim, int jpegQuality, double? atSeconds) async {
    return _impl?.call(path, maxDim, jpegQuality, atSeconds);
  }
}

/// Indirection for getting video duration on mobile.
abstract class PlatformVideoInfoHelper {
  static Future<int?> Function(String)? _impl;

  static void register(Future<int?> Function(String) impl) {
    _impl = impl;
  }

  static Future<int?> getVideoDurationMs(String path) async {
    return _impl?.call(path);
  }
}
