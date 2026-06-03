import 'dart:io';
import 'package:flutter/services.dart';

abstract final class StoragePermissionService {
  static const _channel = MethodChannel('com.pcify.pcify_server/permissions');

  static Future<bool> hasManageStoragePermission() async {
    if (!Platform.isAndroid) return true;
    return await _channel.invokeMethod<bool>('hasManageStoragePermission') ?? true;
  }

  static Future<void> requestManageStoragePermission() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('requestManageStoragePermission');
  }

  /// Opens this app's system settings page, where the user can reach OEM
  /// "Autostart" / "Battery" / "Notifications" screens that have no standard API.
  static Future<void> openAppSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openAppSettings');
  }
}
