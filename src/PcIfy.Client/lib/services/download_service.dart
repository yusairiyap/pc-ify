import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';

class DownloadService {
  DownloadService(this._api);

  final ApiService _api;

  static const _channel = MethodChannel('com.pcify.pcify_client/downloads');

  Future<String?> downloadFile(
    String serverPath,
    String fileName, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      if (Platform.isAndroid) {
        return await _downloadToSystemDownloads(
            serverPath, fileName, onProgress: onProgress);
      }
      final dir = await _getDownloadsDir();
      final savePath = '${dir.path}/$fileName';
      await _api.downloadFile(serverPath, savePath,
          onReceiveProgress: onProgress);
      return savePath;
    } catch (_) {
      return null;
    }
  }

  // Downloads to a temp file first, then hands it to Kotlin which uses
  // MediaStore.Downloads (API 29+) or a direct copy (API < 29) to place
  // the file in the system-visible Downloads folder.
  Future<String> _downloadToSystemDownloads(
    String serverPath,
    String fileName, {
    void Function(int received, int total)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/$fileName';
    try {
      await _api.downloadFile(serverPath, tempPath,
          onReceiveProgress: onProgress);
      final uri = await _channel.invokeMethod<String>('saveToSystemDownloads', {
        'tempPath': tempPath,
        'fileName': fileName,
      });
      return uri!;
    } finally {
      final f = File(tempPath);
      if (await f.exists()) await f.delete();
    }
  }

  Future<Directory> _getDownloadsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/Downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
