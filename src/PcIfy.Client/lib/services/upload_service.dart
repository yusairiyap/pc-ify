import 'package:dio/dio.dart';

import 'api_service.dart';

class UploadService {
  UploadService(this._api);
  final ApiService _api;

  Future<bool> uploadFile(
    String localPath,
    String serverFolderPath,
    String filename, {
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      await _api.uploadFile(
        serverFolderPath,
        filename,
        localPath,
        onSendProgress: onProgress,
        cancelToken: cancelToken,
      );
      return true;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return false;
      return false;
    } catch (_) {
      return false;
    }
  }
}
