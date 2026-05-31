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

  Future<Uint8List?> getOrCreate(
    String filePath,
    List<String> allowedRoots,
    ThumbnailSize size,
  ) async {
    final sanitized = PathSanitizer.sanitize(filePath, allowedRoots);
    if (sanitized == null) return null;

    final ext = p.extension(sanitized).replaceFirst('.', '').toLowerCase();
    if (!MediaTypes.isThumbnailable(ext)) return null;

    final cacheKey = _cacheKey(sanitized, size);
    final cacheFile = File(p.join(await _cachePath, '$cacheKey.jpg'));

    if (await cacheFile.exists()) {
      return cacheFile.readAsBytes();
    }

    Uint8List? result;
    if (MediaTypes.isImage(ext)) {
      result = await compute(_resizeImage, _ResizeParams(sanitized, size.pixels));
    } else if (MediaTypes.isVideo(ext)) {
      result = await _videoThumbnail(sanitized, size.pixels);
    }

    if (result != null) {
      await cacheFile.writeAsBytes(result);
    }
    return result;
  }

  String _cacheKey(String path, ThumbnailSize size) {
    final input = '$path:${size.name}';
    return sha256.convert(input.codeUnits).toString();
  }

  Future<Uint8List?> _videoThumbnail(String videoPath, int maxDim) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return _videoThumbnailMobile(videoPath, maxDim);
    }
    return _videoThumbnailDesktop(videoPath, maxDim);
  }

  /// Mobile: use video_thumbnail plugin via platform channel.
  Future<Uint8List?> _videoThumbnailMobile(
      String videoPath, int maxDim) async {
    // video_thumbnail is a conditional import — only present on Android/iOS.
    // Imported via platform_thumbnail_helper.dart.
    return PlatformThumbnailHelper.getVideoThumbnail(videoPath, maxDim);
  }

  /// Desktop (Windows/macOS): spawn ffmpeg subprocess to extract frame.
  Future<Uint8List?> _videoThumbnailDesktop(
      String videoPath, int maxDim) async {
    final ffmpeg = FFmpegSetupService.ffmpegPath;
    if (ffmpeg == null) return null;

    final tmp = await getTemporaryDirectory();
    final outPath = p.join(
        tmp.path, 'pcify-vt-${DateTime.now().millisecondsSinceEpoch}.jpg');

    try {
      final result = await Process.run(ffmpeg, [
        '-ss', '2',
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
      return compute(_resizeImage, _ResizeParams.fromBytes(frameBytes, maxDim));
    } catch (_) {
      return null;
    }
  }
}

// ── Isolate-safe helpers ──────────────────────────────────────────────────────

class _ResizeParams {
  final String? path;
  final Uint8List? bytes;
  final int maxDim;

  const _ResizeParams(this.path, this.maxDim) : bytes = null;
  const _ResizeParams.fromBytes(this.bytes, this.maxDim) : path = null;
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
  return Uint8List.fromList(img.encodeJpg(thumb, quality: 85));
}

/// Indirection so ThumbnailService doesn't import video_thumbnail directly
/// (that plugin only registers on Android/iOS and would crash on desktop).
abstract class PlatformThumbnailHelper {
  static Future<Uint8List?> Function(String, int)? _impl;

  static void register(Future<Uint8List?> Function(String, int) impl) {
    _impl = impl;
  }

  static Future<Uint8List?> getVideoThumbnail(String path, int maxDim) async {
    return _impl?.call(path, maxDim);
  }
}
