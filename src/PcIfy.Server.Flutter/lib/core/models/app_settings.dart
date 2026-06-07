import 'dart:io';
import 'dart:math';
import 'launcher_app.dart';
import 'user_credential.dart';

class AppSettings {
  final int port;
  final bool autoStart;
  final String serverName;
  final String jwtSecret;
  final int tokenExpiryHours;
  final List<UserCredential> users;
  final List<String> sourceDirectories;
  final String colorMode;
  final bool onboardingCompleted;
  final List<LauncherApp> launcherApps;

  const AppSettings({
    this.port = 8080,
    this.autoStart = true,
    required this.serverName,
    required this.jwtSecret,
    this.tokenExpiryHours = 24,
    this.users = const [],
    this.sourceDirectories = const [],
    this.colorMode = 'System',
    this.onboardingCompleted = false,
    this.launcherApps = const [],
  });

  factory AppSettings.defaults() => AppSettings(
        serverName: _defaultServerName(),
        jwtSecret: _generateSecret(),
      );

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        port: (json['port'] as int?) ?? 8080,
        autoStart: (json['autoStart'] as bool?) ?? true,
        serverName: (json['serverName'] as String?) ?? _defaultServerName(),
        jwtSecret: (json['jwtSecret'] as String?) ?? _generateSecret(),
        tokenExpiryHours: (json['tokenExpiryHours'] as int?) ?? 24,
        users: (json['users'] as List<dynamic>? ?? [])
            .map((e) => UserCredential.fromJson(e as Map<String, dynamic>))
            .toList(),
        sourceDirectories: (json['sourceDirectories'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        colorMode: (json['colorMode'] as String?) ?? 'System',
        onboardingCompleted: (json['onboardingCompleted'] as bool?) ?? false,
        launcherApps: (json['launcherApps'] as List<dynamic>? ?? [])
            .map((e) => LauncherApp.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'port': port,
        'autoStart': autoStart,
        'serverName': serverName,
        'jwtSecret': jwtSecret,
        'tokenExpiryHours': tokenExpiryHours,
        'users': users.map((u) => u.toJson()).toList(),
        'sourceDirectories': sourceDirectories,
        'colorMode': colorMode,
        'onboardingCompleted': onboardingCompleted,
        'launcherApps': launcherApps.map((a) => a.toJson()).toList(),
      };

  AppSettings copyWith({
    int? port,
    bool? autoStart,
    String? serverName,
    String? jwtSecret,
    int? tokenExpiryHours,
    List<UserCredential>? users,
    List<String>? sourceDirectories,
    String? colorMode,
    bool? onboardingCompleted,
    List<LauncherApp>? launcherApps,
  }) =>
      AppSettings(
        port: port ?? this.port,
        autoStart: autoStart ?? this.autoStart,
        serverName: serverName ?? this.serverName,
        jwtSecret: jwtSecret ?? this.jwtSecret,
        tokenExpiryHours: tokenExpiryHours ?? this.tokenExpiryHours,
        users: users ?? this.users,
        sourceDirectories: sourceDirectories ?? this.sourceDirectories,
        colorMode: colorMode ?? this.colorMode,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        launcherApps: launcherApps ?? this.launcherApps,
      );

  static String _defaultServerName() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'pc-ify-server';
    }
  }

  static String _generateSecret() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
