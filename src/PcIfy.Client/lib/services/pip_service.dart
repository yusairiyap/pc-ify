import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Thin wrapper around the native Android Picture-in-Picture API.
/// Has no effect on non-Android platforms.
class PipService {
  PipService._();

  static const _channel = MethodChannel('com.pcify.pcify_client/pip');

  // Set this before calling [initialize] or update it any time.
  static void Function(bool isInPip)? onPipChanged;

  /// Registers the method-call handler that receives push events from Android.
  /// Call once, e.g. in a screen's initState.
  static void initialize() {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipChanged') {
        onPipChanged?.call(call.arguments as bool);
      }
    });
  }

  /// Removes the handler. Call in dispose.
  static void dispose() {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler(null);
    onPipChanged = null;
  }

  /// Returns true if the device supports PiP (Android 8+).
  static Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Enters Picture-in-Picture mode with the given aspect ratio.
  static Future<void> enter({int ratioNum = 16, int ratioDen = 9}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(
        'enterPipMode',
        {'ratioNum': ratioNum, 'ratioDen': ratioDen},
      );
    } on PlatformException {
      // Device doesn't support PiP — silently ignore.
    }
  }
}
