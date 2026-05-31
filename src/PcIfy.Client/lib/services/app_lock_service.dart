import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLockType { none, biometric, pin, password }

class AppLockService {
  AppLockService(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _keyType = 'app_lock_type';
  static const _keyGrace = 'app_lock_grace_seconds';
  static const _keyHash = 'app_lock_credential_hash';

  AppLockType getLockType() {
    final raw = _prefs.getString(_keyType) ?? 'none';
    return switch (raw) {
      'biometric' => AppLockType.biometric,
      'pin' => AppLockType.pin,
      'password' => AppLockType.password,
      _ => AppLockType.none,
    };
  }

  Future<void> setLockType(AppLockType type) {
    final raw = switch (type) {
      AppLockType.biometric => 'biometric',
      AppLockType.pin => 'pin',
      AppLockType.password => 'password',
      AppLockType.none => 'none',
    };
    return _prefs.setString(_keyType, raw);
  }

  bool get isEnabled => getLockType() != AppLockType.none;

  int get gracePeriodSeconds => _prefs.getInt(_keyGrace) ?? 0;

  Future<void> setGracePeriod(int seconds) =>
      _prefs.setInt(_keyGrace, seconds);

  Future<void> saveCredential(String plaintext) =>
      _secure.write(key: _keyHash, value: _hash(plaintext));

  Future<bool> verifyCredential(String plaintext) async {
    final stored = await _secure.read(key: _keyHash);
    return stored != null && stored == _hash(plaintext);
  }

  Future<void> clearCredential() => _secure.delete(key: _keyHash);

  String _hash(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}
