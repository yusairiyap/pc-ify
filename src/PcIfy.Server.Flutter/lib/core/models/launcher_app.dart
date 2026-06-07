class LauncherApp {
  const LauncherApp({
    required this.id,
    required this.name,
    required this.executablePath,
    this.processName,
    this.iconKey,
  });
  final String id;
  final String name;
  final String executablePath;
  final String? processName;
  final String? iconKey;

  factory LauncherApp.fromJson(Map<String, dynamic> j) => LauncherApp(
    id: (j['id'] as String?) ?? '',
    name: (j['name'] as String?) ?? '',
    executablePath: (j['executablePath'] as String?) ?? '',
    processName: j['processName'] as String?,
    iconKey: j['iconKey'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'executablePath': executablePath,
    if (processName != null) 'processName': processName,
    if (iconKey != null) 'iconKey': iconKey,
  };
}
