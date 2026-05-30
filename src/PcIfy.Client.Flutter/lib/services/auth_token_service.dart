import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenService {
  AuthTokenService(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'auth_token';

  Future<void> saveToken(String token) => _storage.write(key: _key, value: token);

  Future<String?> getToken() => _storage.read(key: _key);

  Future<void> clearToken() => _storage.delete(key: _key);

  Future<bool> isTokenValid() async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final jwt = JWT.decode(token);
      final exp = jwt.payload['exp'] as int?;
      if (exp == null) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      return expiry.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 5)));
    } catch (_) {
      return false;
    }
  }
}
