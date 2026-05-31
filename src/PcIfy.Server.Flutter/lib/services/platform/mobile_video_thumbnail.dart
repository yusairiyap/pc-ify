import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:video_thumbnail/video_thumbnail.dart';

/// Called only on Android/iOS via PlatformThumbnailHelper.register in main.dart.
Future<Uint8List?> getMobileVideoThumbnail(String path, int maxDim) async {
  final bytes = await VideoThumbnail.thumbnailData(
    video: path,
    imageFormat: ImageFormat.JPEG,
    maxWidth: maxDim,
    quality: 85,
    timeMs: 2000,
  );
  if (bytes == null) return null;

  // Ensure thumbnail fits within maxDim while preserving aspect ratio.
  final src = img.decodeImage(bytes);
  if (src == null) return bytes;
  if (src.width <= maxDim && src.height <= maxDim) return bytes;

  final resized = img.copyResize(
    src,
    width: src.width > src.height ? maxDim : -1,
    height: src.height >= src.width ? maxDim : -1,
    interpolation: img.Interpolation.linear,
  );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}
