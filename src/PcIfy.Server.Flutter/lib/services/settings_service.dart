import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/models/app_settings.dart';
import '../core/models/user_credential.dart';
import 'auth_service.dart';

class SettingsService {
  AppSettings _settings = AppSettings.defaults();
  AppSettings get settings => _settings;

  Future<String> get _settingsPath async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'settings.json');
  }

  Future<void> load() async {
    // On Windows, try the legacy C# path first so existing installs migrate.
    if (Platform.isWindows) {
      final legacy = _legacyWindowsPath();
      if (legacy != null) {
        final file = File(legacy);
        if (await file.exists()) {
          await _readFile(file);
          // Persist to new location then remove legacy file so subsequent
          // launches read from the new path and don't clobber saved changes.
          await save();
          await file.delete();
          return;
        }
      }
    }

    final path = await _settingsPath;
    final file = File(path);
    if (!await file.exists()) {
      await _createDefaults();
      return;
    }
    await _readFile(file);
    if (_settings.users.isEmpty) {
      await _seedDefaultUser();
    }
  }

  Future<void> save() async {
    final path = await _settingsPath;
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_settings.toJson()),
    );
  }

  Future<void> update(AppSettings updated) async {
    _settings = updated;
    await save();
  }

  Future<void> _readFile(File file) async {
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _settings = AppSettings.fromJson(json);
    } catch (_) {
      await _createDefaults();
    }
  }

  Future<void> _createDefaults() async {
    _settings = AppSettings.defaults();
    // On Android, replace the hostname default with the actual device model name.
    if (Platform.isAndroid) {
      try {
        const ch = MethodChannel('com.pcify.pcify_server/system_control');
        final name = await ch.invokeMethod<String>('getDeviceName');
        if (name != null && name.isNotEmpty) {
          _settings = _settings.copyWith(serverName: name);
        }
      } catch (_) {}
    }
    await _seedDefaultUser();
  }

  Future<void> _seedDefaultUser() async {
    final defaultUser = UserCredential(
      username: 'admin',
      passwordHash: AuthService.hashPassword('admin'),
    );
    _settings = _settings.copyWith(users: [defaultUser]);
    await save();
  }

  static String? _legacyWindowsPath() {
    final appData = Platform.environment['APPDATA'];
    if (appData == null) return null;
    return p.join(appData, 'pcify', 'settings.json');
  }
}
