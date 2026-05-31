class ConnectionLogEntry {
  final DateTime timestamp;
  final String clientIp;
  final String username;
  final String method;
  final String path;
  final int statusCode;

  const ConnectionLogEntry({
    required this.timestamp,
    required this.clientIp,
    required this.username,
    required this.method,
    required this.path,
    required this.statusCode,
  });
}
