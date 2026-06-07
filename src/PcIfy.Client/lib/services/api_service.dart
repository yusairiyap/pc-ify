import 'dart:io';

import 'package:dio/dio.dart';

import '../core/constants/api_routes.dart';
import '../core/models/control_status.dart';
import '../core/models/folder_listing.dart';
import '../core/models/login_response.dart';
import '../core/models/server_info.dart';
import 'auth_token_service.dart';
import 'connection_service.dart';

class ApiService {
  ApiService(this._dio, this._auth, this._connection);

  final Dio _dio;
  final AuthTokenService _auth;
  final ConnectionService _connection;

  String get _base => _connection.baseUrl;

  Future<LoginResponse?> login(String username, String password) async {
    try {
      final resp = await _dio.post(
        '$_base${ApiRoutes.login}',
        data: {'username': username, 'password': password},
      );
      return LoginResponse.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> ping() async {
    try {
      final resp = await _dio.get('$_base${ApiRoutes.health}');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<ServerInfo?> getServerInfo() async {
    try {
      final resp = await _dio.get('$_base${ApiRoutes.info}');
      return ServerInfo.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<({String path, String name})>?> getRoots() async {
    try {
      final resp = await _dio.get('$_base${ApiRoutes.roots}');
      final list = resp.data as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return (path: m['path'] as String, name: m['displayName'] as String);
      }).toList();
    } catch (_) {
      return null;
    }
  }

  Future<FolderListing?> getFolderListing(String path) async {
    try {
      final resp = await _dio.get(
        '$_base${ApiRoutes.list}',
        queryParameters: {'path': path},
      );
      return FolderListing.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403) throw Exception('Access denied.');
      if (status == 404) throw Exception('Folder not found.');
      if (status != null) throw Exception('Server error $status.');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> _token() => _auth.getToken();

  String buildStreamUri(String serverPath) {
    final encoded = Uri.encodeComponent(serverPath);
    return '$_base${ApiRoutes.stream}/$encoded';
  }

  String buildDownloadUri(String serverPath) {
    final encoded = Uri.encodeComponent(serverPath);
    return '$_base${ApiRoutes.download}/$encoded';
  }

  String buildThumbnailUri(String serverPath,
      {int quality = 50, double? atSeconds}) {
    final encoded = Uri.encodeComponent(serverPath);
    var url = '$_base${ApiRoutes.thumbnails}/$encoded?quality=$quality';
    if (atSeconds != null) url += '&t=${atSeconds.toStringAsFixed(2)}';
    return url;
  }

  Future<String> buildStreamUriWithToken(String serverPath) async {
    final base = buildStreamUri(serverPath);
    final token = await _token();
    if (token == null) return base;
    return '$base?${ApiRoutes.tokenParam}=${Uri.encodeComponent(token)}';
  }

  Future<String> buildDownloadUriWithToken(String serverPath) async {
    final base = buildDownloadUri(serverPath);
    final token = await _token();
    if (token == null) return base;
    return '$base?${ApiRoutes.tokenParam}=${Uri.encodeComponent(token)}';
  }

  Future<String> buildThumbnailUriWithToken(String serverPath,
      {int quality = 50, double? atSeconds}) async {
    final base = buildThumbnailUri(serverPath, quality: quality, atSeconds: atSeconds);
    final token = await _token();
    if (token == null) return base;
    return '$base&${ApiRoutes.tokenParam}=${Uri.encodeComponent(token)}';
  }

  Future<int?> getVideoDurationMs(String serverPath) async {
    try {
      final token = await _token();
      final encoded = Uri.encodeComponent(serverPath);
      final tokenPart = token != null
          ? '&${ApiRoutes.tokenParam}=${Uri.encodeComponent(token)}'
          : '';
      final resp = await _dio.get(
          '$_base${ApiRoutes.videoInfo}?path=$encoded$tokenPart');
      return (resp.data as Map<String, dynamic>)['durationMs'] as int?;
    } catch (_) {
      return null;
    }
  }

  Future<void> downloadFile(
    String serverPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final uri = await buildDownloadUriWithToken(serverPath);
    await _dio.download(
      uri,
      savePath,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
      options: Options(receiveTimeout: Duration.zero),
    );
  }

  Future<void> uploadFile(
    String serverFolderPath,
    String filename,
    String localPath, {
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final file = File(localPath);
    final length = await file.length();
    final encodedFolder = Uri.encodeComponent(serverFolderPath);
    final encodedFilename = Uri.encodeComponent(filename);
    final url =
        '$_base${ApiRoutes.upload}?path=$encodedFolder&filename=$encodedFilename';
    await _dio.post(
      url,
      data: file.openRead(),
      options: Options(
        contentType: 'application/octet-stream',
        headers: {'content-length': length.toString()},
        sendTimeout: Duration.zero,
        receiveTimeout: const Duration(seconds: 60),
      ),
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
  }

  Future<bool> deleteFile(String path) async {
    try {
      await _dio.delete(
        '$_base${ApiRoutes.filesDelete}',
        queryParameters: {'path': path},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> copyFile(String src, String destFolder) async {
    try {
      await _dio.post(
        '$_base${ApiRoutes.filesCopy}',
        data: {'src': src, 'destFolder': destFolder},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> moveFile(String src, String destFolder) async {
    try {
      await _dio.post(
        '$_base${ApiRoutes.filesMove}',
        data: {'src': src, 'destFolder': destFolder},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<ControlStatus?> getControlStatus() async {
    try {
      final resp = await _dio.get('$_base${ApiRoutes.controlStatus}');
      return ControlStatus.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> setVolume(int level) async {
    try {
      await _dio.post('$_base${ApiRoutes.controlVolume}', data: {'level': level});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setMute(bool muted) async {
    try {
      await _dio.post('$_base${ApiRoutes.controlMute}', data: {'muted': muted});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> lockScreen() async {
    try {
      await _dio.post('$_base${ApiRoutes.controlLock}');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> wakeScreen() async {
    try {
      await _dio.post('$_base${ApiRoutes.controlWake}');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<PcClipboardStatus?> getClipboard() async {
    try {
      final resp = await _dio.get('$_base${ApiRoutes.controlClipboard}');
      return PcClipboardStatus.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<AppLauncherStatus?> getApps() async {
    try {
      final resp = await _dio.get('$_base${ApiRoutes.systemApps}');
      return AppLauncherStatus.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> launchApp(String id) async {
    try {
      await _dio.post('$_base${ApiRoutes.systemAppsLaunch}', data: {'id': id});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<LauncherAppInfo?> addLauncherApp({
    required String name,
    required String executablePath,
    String? processName,
    String? iconKey,
  }) async {
    try {
      final resp = await _dio.post('$_base${ApiRoutes.systemAppsAdd}', data: {
        'name': name,
        'executablePath': executablePath,
        if (processName != null && processName.isNotEmpty) 'processName': processName,
        if (iconKey != null && iconKey.isNotEmpty) 'iconKey': iconKey,
      });
      return LauncherAppInfo.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> removeLauncherApp(String id) async {
    try {
      await _dio.delete('$_base${ApiRoutes.systemApps}/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

}
