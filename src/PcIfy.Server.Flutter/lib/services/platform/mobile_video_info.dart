import 'package:flutter/services.dart';

const _channel = MethodChannel('com.pcify.pcify_server/system_control');

Future<int?> getMobileVideoDurationMs(String path) async {
  try {
    final ms = await _channel.invokeMethod<int>(
        'getVideoDurationMs', {'path': path});
    return ms;
  } catch (_) {
    return null;
  }
}
