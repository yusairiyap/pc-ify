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
      // Try the public Downloads directory on Android
      final dir = Directory('/storage/emulated/0/Download');
      if (dir.existsSync()) return dir;
    }
    // Fallback: app documents directory with a Downloads subfolder
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/Downloads');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
}
