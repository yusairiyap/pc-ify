import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/auth_token_service.dart';
import '../services/backup_restore_service.dart';
import '../services/bookmark_service.dart';
import '../services/connection_service.dart';
import '../services/dashboard_layout_service.dart';
import '../services/download_service.dart';
import '../services/external_player_service.dart';
import '../services/upload_service.dart';
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

/// Incremented whenever folder prefs are bulk-changed (e.g. after a restore),
/// so persistent screens like HomeScreen know to reload their background.
final folderPrefsVersionProvider = StateProvider<int>((ref) => 0);

final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  return BackupRestoreService(
    ref.watch(sharedPrefsProvider),
    ref.watch(bookmarkServiceProvider),
    ref.watch(folderPrefsServiceProvider),
  );
});

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService(ref.watch(apiServiceProvider));
});

final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(ref.watch(apiServiceProvider));
});

final externalPlayerServiceProvider = Provider<ExternalPlayerService>((ref) {
  return ExternalPlayerService();
});

final themeServiceProvider = Provider<ThemeService>((ref) {
  return ThemeService(ref.watch(sharedPrefsProvider));
});

// Persisted video fit mode: 'contain' | 'cover' | 'fill'. Default: 'contain'.
final videoFitProvider = StateProvider<BoxFit>((ref) {
  final s = ref.watch(sharedPrefsProvider).getString('video_fit_mode') ?? 'contain';
  return switch (s) {
    'cover' => BoxFit.cover,
    'fill' => BoxFit.fill,
    _ => BoxFit.contain,
  };
});

// Persisted auto-repeat toggle. Default: false.
final videoRepeatProvider = StateProvider<bool>((ref) {
  return ref.watch(sharedPrefsProvider).getBool('video_auto_repeat') ?? false;
});

final dashboardLayoutServiceProvider = Provider<DashboardLayoutService>((ref) {
  return DashboardLayoutService(ref.watch(sharedPrefsProvider));
});

/// Dashboard widget poll interval in seconds. Default: 5. Persisted to SharedPreferences.
final dashboardPollIntervalProvider = StateProvider<int>((ref) {
  return ref.watch(sharedPrefsProvider).getInt('dashboard_poll_interval') ?? 5;
});
