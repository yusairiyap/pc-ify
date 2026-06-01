import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../core/constants/api_routes.dart';
import '../core/models/app_settings.dart';
import '../core/models/connection_log_entry.dart';
import 'auth_service.dart';
import 'connection_log_service.dart';
import 'file_service.dart';
import 'thumbnail_service.dart';

class ServerState {
  final bool isRunning;
  final int? port;
  final List<String> ipAddresses;

  const ServerState({
    required this.isRunning,
    this.port,
    this.ipAddresses = const [],
  });

  static const stopped = ServerState(isRunning: false);
}

class HttpServerService {
  final AppSettings settings;
  final ConnectionLogService logService;

  HttpServerService(this.settings, this.logService);

  HttpServer? _server;
  final _stateController = StreamController<ServerState>.broadcast();

  Stream<ServerState> get stateStream => _stateController.stream;
  bool get isRunning => _server != null;
  int? get currentPort => _server?.port;

  Future<void> start(int port) async {
    if (isRunning) await stop();

    final authSvc = AuthService(settings);
    final fileSvc = FileService(settings);
    final thumbSvc = ThumbnailService();

    final router = _buildRouter(authSvc, fileSvc, thumbSvc);
    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_loggingMiddleware(authSvc))
        .addHandler(router.call);

    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      port,
      shared: false,
    );

    final ips = await _getLocalIps();
    _stateController.add(
        ServerState(isRunning: true, port: port, ipAddresses: ips));
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _stateController.add(ServerState.stopped);
  }

  Future<void> dispose() async {
    await stop();
    _stateController.close();
  }

  // ── Router ────────────────────────────────────────────────────────────────

  Router _buildRouter(
    AuthService authSvc,
    FileService fileSvc,
    ThumbnailService thumbSvc,
  ) {
    final r = Router();

    // Public endpoints
    r.post(ApiRoutes.authLogin, (Request req) => _handleLogin(req, authSvc));
    r.get(ApiRoutes.systemHealth, (_) => _json({'status': 'ok'}));
    r.get(ApiRoutes.systemInfo, (_) => _handleSystemInfo());

    // Protected endpoints
    r.get(ApiRoutes.filesRoots,
        _withAuth(authSvc, (req) => _handleRoots(req, fileSvc, authSvc)));
    r.get(ApiRoutes.filesList,
        _withAuth(authSvc, (req) => _handleList(req, fileSvc, authSvc)));
    r.get(
        '${ApiRoutes.filesStream}/<filePath|[^]*>',
        _streamGuard(authSvc,
            (req, fp) => _handleStream(req, fp, fileSvc, authSvc)));
    r.get(
        '${ApiRoutes.filesDownload}/<filePath|[^]*>',
        _streamGuard(authSvc,
            (req, fp) => _handleDownload(req, fp, fileSvc, authSvc)));
    r.get(
        '${ApiRoutes.thumbnails}/<filePath|[^]*>',
        _streamGuard(authSvc,
            (req, fp) => _handleThumbnail(req, fp, fileSvc, thumbSvc, authSvc)));

    r.all('/<ignored|.*>', (_) => Response.notFound('Not found'));
    return r;
  }

  // ── Auth handlers ─────────────────────────────────────────────────────────

  Future<Response> _handleLogin(Request req, AuthService authSvc) async {
    final Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(await req.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return Response.badRequest(body: 'Expected JSON object');
      }
      body = decoded;
    } catch (_) {
      return Response.badRequest(body: 'Invalid JSON');
    }
    final username = body['username'] as String? ?? '';
    final password = body['password'] as String? ?? '';

    if (!authSvc.validateCredentials(username, password)) {
      return Response.unauthorized(
          jsonEncode({'error': 'Invalid credentials'}),
          headers: {'content-type': 'application/json'});
    }
    final token = authSvc.generateToken(username);
    final expiresAt =
        DateTime.now().add(Duration(hours: settings.tokenExpiryHours));
    return _json({
      'token': token,
      'expiresAt': expiresAt.toIso8601String(),
    });
  }

  // ── System handlers ───────────────────────────────────────────────────────

  Response _handleSystemInfo() {
    return _json({
      'serverName': settings.serverName,
      'version': '1.0.0',
      'osVersion': Platform.operatingSystemVersion,
    });
  }

  // ── Per-user directory access helpers ────────────────────────────────────

  String? _getUsername(Request req, AuthService authSvc) {
    final token = _extractToken(req);
    if (token == null) return null;
    return authSvc.verifyToken(token);
  }

  List<String> _effectiveRoots(String? username) {
    if (username == null) return settings.sourceDirectories;
    final user = settings.users.where(
      (u) => u.username.toLowerCase() == username.toLowerCase(),
    ).firstOrNull;
    if (user == null || user.allowedDirectories.isEmpty) {
      return settings.sourceDirectories;
    }
    return user.allowedDirectories;
  }

  // ── File handlers ─────────────────────────────────────────────────────────

  Response _handleRoots(Request req, FileService fileSvc, AuthService authSvc) {
    final roots = _effectiveRoots(_getUsername(req, authSvc));
    return _json(fileSvc.getRoots(allowedRoots: roots).map((r) => r.toJson()).toList());
  }

  Future<Response> _handleList(
    Request req,
    FileService fileSvc,
    AuthService authSvc,
  ) async {
    final path = req.url.queryParameters['path'];
    if (path == null) {
      return Response.badRequest(body: 'Missing path parameter');
    }
    final roots = _effectiveRoots(_getUsername(req, authSvc));
    final listing = await fileSvc.getFolderListing(path, allowedRoots: roots);
    if (listing == null) {
      return Response.forbidden('Path not allowed or not found');
    }
    return _json(listing.toJson());
  }

  Future<Response> _handleStream(
    Request req,
    String encodedPath,
    FileService fileSvc,
    AuthService authSvc,
  ) async {
    final filePath = Uri.decodeComponent(encodedPath);
    final roots = _effectiveRoots(_getUsername(req, authSvc));
    if (!fileSvc.isPathAllowed(filePath, allowedRoots: roots)) {
      return Response.forbidden('Path not allowed');
    }

    final size = await fileSvc.getFileSize(filePath, allowedRoots: roots);
    if (size == null) return Response.notFound('File not found');

    final mimeType = fileSvc.getMimeType(filePath);
    final rangeHeader = req.headers['range'];

    if (rangeHeader != null) {
      final range = _parseRange(rangeHeader, size);
      if (range == null) {
        return Response(416, headers: {'content-range': 'bytes */$size'});
      }
      final stream = fileSvc.openStream(filePath,
          start: range.$1, end: range.$2, allowedRoots: roots);
      if (stream == null) return Response.internalServerError();

      final length = range.$2 - range.$1 + 1;
      return Response(
        206,
        body: stream,
        headers: {
          'content-type': mimeType,
          'content-length': '$length',
          'content-range': 'bytes ${range.$1}-${range.$2}/$size',
          'accept-ranges': 'bytes',
        },
      );
    }

    final stream = fileSvc.openStream(filePath, allowedRoots: roots);
    if (stream == null) return Response.internalServerError();
    return Response.ok(stream, headers: {
      'content-type': mimeType,
      'content-length': '$size',
      'accept-ranges': 'bytes',
    });
  }

  Future<Response> _handleDownload(
    Request req,
    String encodedPath,
    FileService fileSvc,
    AuthService authSvc,
  ) async {
    final filePath = Uri.decodeComponent(encodedPath);
    final roots = _effectiveRoots(_getUsername(req, authSvc));
    if (!fileSvc.isPathAllowed(filePath, allowedRoots: roots)) {
      return Response.forbidden('Path not allowed');
    }

    final size = await fileSvc.getFileSize(filePath, allowedRoots: roots);
    if (size == null) return Response.notFound('File not found');

    final fileName = p.basename(filePath);
    final mimeType = fileSvc.getMimeType(filePath);
    final stream = fileSvc.openStream(filePath, allowedRoots: roots);
    if (stream == null) return Response.internalServerError();

    return Response.ok(stream, headers: {
      'content-type': mimeType,
      'content-length': '$size',
      'content-disposition': 'attachment; filename="$fileName"',
    });
  }

  Future<Response> _handleThumbnail(
    Request req,
    String encodedPath,
    FileService fileSvc,
    ThumbnailService thumbSvc,
    AuthService authSvc,
  ) async {
    final filePath = Uri.decodeComponent(encodedPath);
    final roots = _effectiveRoots(_getUsername(req, authSvc));
    if (!fileSvc.isPathAllowed(filePath, allowedRoots: roots)) {
      return Response.forbidden('Path not allowed');
    }

    final sizeParam = req.url.queryParameters['size'];
    final size = ThumbnailSizeExt.fromString(sizeParam);
    final bytes = await thumbSvc.getOrCreate(filePath, roots, size);
    if (bytes == null) return Response.notFound('Cannot generate thumbnail');

    return Response.ok(bytes, headers: {'content-type': 'image/jpeg'});
  }

  // ── Middleware factories ───────────────────────────────────────────────────

  Middleware _corsMiddleware() {
    return (Handler inner) => (Request req) async {
          if (req.method == 'OPTIONS') {
            return Response.ok('', headers: _corsHeaders());
          }
          final res = await inner(req);
          return res.change(headers: _corsHeaders());
        };
  }

  static Map<String, String> _corsHeaders() => {
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'access-control-allow-headers':
            'Content-Type, Authorization, Range',
      };

  Middleware _loggingMiddleware(AuthService authSvc) {
    return (Handler inner) => (Request req) async {
          final res = await inner(req);
          final token = _extractToken(req);
          final username = token != null ? authSvc.verifyToken(token) ?? '' : '';
          logService.log(ConnectionLogEntry(
            timestamp: DateTime.now(),
            clientIp: req.headers['x-forwarded-for'] ??
                (req.context['shelf.io.connection_info'] as HttpConnectionInfo?)
                    ?.remoteAddress.address ??
                'unknown',
            username: username,
            method: req.method,
            path: '/${req.url}',
            statusCode: res.statusCode,
          ));
          return res;
        };
  }

  // ── Auth middleware helpers ───────────────────────────────────────────────

  /// Wraps a no-param handler to require Bearer token auth (header only).
  Handler _withAuth(
    AuthService authSvc,
    FutureOr<Response> Function(Request) inner,
  ) {
    return (Request req) async {
      final token = _bearerToken(req);
      if (token == null || authSvc.verifyToken(token) == null) {
        return Response.unauthorized('Unauthorized',
            headers: {'www-authenticate': 'Bearer'});
      }
      return inner(req);
    };
  }

  /// Wraps a shelf_router param handler (Request, String filePath) to require
  /// Bearer token OR ?token= query param (needed for streaming/thumbnail routes).
  FutureOr<Response> Function(Request, String) _streamGuard(
    AuthService authSvc,
    FutureOr<Response> Function(Request, String) inner,
  ) {
    return (Request req, String filePath) async {
      final token = _extractToken(req);
      if (token == null || authSvc.verifyToken(token) == null) {
        return Response.unauthorized('Unauthorized',
            headers: {'www-authenticate': 'Bearer'});
      }
      return inner(req, filePath);
    };
  }

  String? _bearerToken(Request req) {
    final auth = req.headers['authorization'];
    if (auth == null || !auth.startsWith('Bearer ')) return null;
    return auth.substring(7);
  }

  String? _extractToken(Request req) {
    return _bearerToken(req) ??
        req.url.queryParameters[ApiRoutes.tokenQueryParam];
  }

  // ── Range request parsing ─────────────────────────────────────────────────

  (int, int)? _parseRange(String header, int totalSize) {
    final match = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(header);
    if (match == null) return null;
    final startStr = match.group(1) ?? '';
    final endStr = match.group(2) ?? '';

    // Suffix-range: bytes=-N → last N bytes (RFC 9110 §14.1.2).
    if (startStr.isEmpty && endStr.isNotEmpty) {
      final suffixLen = int.tryParse(endStr);
      if (suffixLen == null || suffixLen <= 0) return null;
      final start = totalSize - min<int>(suffixLen, totalSize);
      return (start, totalSize - 1);
    }

    final start = startStr.isEmpty ? 0 : int.tryParse(startStr) ?? 0;
    // RFC 9110 §14.1.2: if last-byte-pos >= content length, treat as
    // content-length - 1 (satisfiable, not 416).
    final end = endStr.isEmpty
        ? totalSize - 1
        : min<int>(int.tryParse(endStr) ?? totalSize - 1, totalSize - 1);

    if (start >= totalSize || start > end) return null;
    return (start, end);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Response _json(Object data, {int status = 200}) => Response(
        status,
        body: jsonEncode(data),
        headers: {'content-type': 'application/json'},
      );

  Future<List<String>> _getLocalIps() async {
    // On Android, NetworkInterface.list() may return empty or fail even with
    // INTERNET permission. Use network_info_plus to get the WiFi IP directly.
    if (Platform.isAndroid) {
      try {
        final ip = await NetworkInfo().getWifiIP();
        if (ip != null && ip.isNotEmpty) return [ip];
      } catch (_) {}
      return [];
    }

    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLinkLocal: false);
      return interfaces
          .expand((i) => i.addresses)
          .where((a) => !a.isLoopback && !a.address.startsWith('169.254'))
          .map((a) => a.address)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
