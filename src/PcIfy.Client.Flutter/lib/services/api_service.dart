import 'package:dio/dio.dart';

import '../core/constants/api_routes.dart';
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
        return (path: m['path'] as String, name: m['name'] as String);
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
    } catch (_) {
      return null;
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

  String buildThumbnailUri(String serverPath, {String size = 'medium'}) {
    final encoded = Uri.encodeComponent(serverPath);
    return '$_base${ApiRoutes.thumbnails}/$encoded?size=$size';
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
      {String size = 'medium'}) async {
    final base = buildThumbnailUri(serverPath, size: size);
    final token = await _token();
    if (token == null) return base;
    return '$base&${ApiRoutes.tokenParam}=${Uri.encodeComponent(token)}';
  }

  Future<void> downloadFile(
    String serverPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
  }) async {
    final uri = await buildDownloadUriWithToken(serverPath);
    await _dio.download(uri, savePath, onReceiveProgress: onReceiveProgress);
  }
}
