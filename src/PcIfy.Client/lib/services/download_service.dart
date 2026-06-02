import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'api_service.dart';

class DownloadService {
  DownloadService(this._api);

  final ApiService _api;

  Future<String?> downloadFile(
    String serverPath,
    String fileName, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await _getDownloadsDir();
      final savePath = '${dir.path}/$fileName';
      await _api.downloadFile(
        serverPath,
        savePath,
        onReceiveProgress: onProgress,
      );
      return savePath;
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _getDownloadsDir() async {
    if (Platform.isAndroid) {
      // Android 10+ (API 29+) enforces scoped storage — writing directly to
      // /storage/emulated/0/Download fails without MANAGE_EXTERNAL_STORAGE.
      // getExternalStorageDirectory() returns the app-specific external path
      // (/Android/data/<pkg>/files/) which is always writable without special
      // permissions on any Android version.
      final external = await getExternalStorageDirectory();
      if (external != null) {
        final dir = Directory('${external.path}/Downloads');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    }
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/Downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
