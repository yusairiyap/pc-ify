class ServerInfo {
  const ServerInfo({
    required this.serverName,
    required this.version,
    required this.osVersion,
  });

  final String serverName;
  final String version;
  final String osVersion;

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
        serverName: json['serverName'] as String,
        version: json['version'] as String,
        osVersion: json['osVersion'] as String,
      );
}
