import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../core/models/app_settings.dart';

class AuthService {
  final AppSettings settings;

  AuthService(this.settings);

  bool validateCredentials(String username, String password) {
    final user = settings.users
        .where((u) => u.username.toLowerCase() == username.toLowerCase())
        .firstOrNull;
    if (user == null) return false;
    return BCrypt.checkpw(password, user.passwordHash);
  }

  String generateToken(String username) {
    final jwt = JWT(
      {'sub': username, 'name': username},
      issuer: 'pcify-server',
      audience: Audience(['pcify-client']),
    );
    return jwt.sign(
      SecretKey(settings.jwtSecret),
      algorithm: JWTAlgorithm.HS256,
      expiresIn: Duration(hours: settings.tokenExpiryHours),
    );
  }

  /// Verifies a token and returns the username claim, or null if invalid.
  String? verifyToken(String token) {
    try {
      final jwt = JWT.verify(
        token,
        SecretKey(settings.jwtSecret),
        checkHeaderType: false,
        audience: Audience(['pcify-client']),
        issuer: 'pcify-server',
      );
      return jwt.payload['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  static String hashPassword(String password) =>
      BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 12));
}
