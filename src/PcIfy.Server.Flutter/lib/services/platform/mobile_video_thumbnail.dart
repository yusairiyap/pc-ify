import 'package:flutter/services.dart';

const _channel = MethodChannel('com.pcify.pcify_server/system_control');

Future<Uint8List?> getMobileVideoThumbnail(
    String path, int maxDim, int jpegQuality, double? atSeconds) async {
  try {
    final bytes = await _channel.invokeMethod<Uint8List>('getVideoThumbnail', {
      'path': path,
      'quality': jpegQuality,
      'atSeconds': atSeconds ?? 2.0,
    });
    return bytes;
  } catch (_) {
    return null;
  }
}
