import 'dart:typed_data';

// Android video thumbnails are stubbed out. No stable Flutter plugin exists
// that compiles on both Android and Windows without breaking Gradle or the
// Windows AOT compiler. Returns null so the thumbnail service falls back
// gracefully (no cached entry, client shows a placeholder).
Future<Uint8List?> getMobileVideoThumbnail(String path, int maxDim) async =>
    null;
