import 'package:shared_preferences/shared_preferences.dart';

class ConnectionService {
  ConnectionService(this._prefs);

  final SharedPreferences _prefs;
  static const _baseUrlKey = 'server_base_url';

  String get baseUrl => _prefs.getString(_baseUrlKey) ?? '';

  bool get isConfigured => baseUrl.isNotEmpty;

  Future<void> setBaseUrl(String url) => _prefs.setString(_baseUrlKey, url);
}
