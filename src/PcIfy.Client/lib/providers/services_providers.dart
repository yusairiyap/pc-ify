import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/auth_token_service.dart';
import '../services/bookmark_service.dart';
import '../services/connection_service.dart';
import '../services/download_service.dart';
import '../services/external_player_service.dart';
import '../services/folder_prefs_service.dart';
import '../services/theme_service.dart';
import 'http_providers.dart';

// SharedPreferences must be initialized before the app starts
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPrefsProvider in main()');
});

final authTokenServiceProvider = Provider<AuthTokenService>((ref) {
  return AuthTokenService(const FlutterSecureStorage());
});

final connectionServiceProvider = Provider<ConnectionService>((ref) {
  return ConnectionService(ref.watch(sharedPrefsProvider));
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(
    ref.watch(dioProvider),
    ref.watch(authTokenServiceProvider),
    ref.watch(connectionServiceProvider),
  );
});

final bookmarkServiceProvider = Provider<BookmarkService>((ref) {
  return BookmarkService(ref.watch(sharedPrefsProvider));
});

final folderPrefsServiceProvider = Provider<FolderPrefsService>((ref) {
  return FolderPrefsService();
});

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService(ref.watch(apiServiceProvider));
});

final externalPlayerServiceProvider = Provider<ExternalPlayerService>((ref) {
  return ExternalPlayerService();
});

final themeServiceProvider = Provider<ThemeService>((ref) {
  return ThemeService(ref.watch(sharedPrefsProvider));
});
