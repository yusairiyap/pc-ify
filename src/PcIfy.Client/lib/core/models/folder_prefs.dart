class FolderPrefs {
  const FolderPrefs({this.backgroundImagePath});

  final String? backgroundImagePath;

  factory FolderPrefs.fromJson(Map<String, dynamic> json) => FolderPrefs(
        backgroundImagePath: json['backgroundImagePath'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'backgroundImagePath': backgroundImagePath,
      };

  FolderPrefs copyWith({String? backgroundImagePath, bool clearBackground = false}) =>
      FolderPrefs(
        backgroundImagePath:
            clearBackground ? null : (backgroundImagePath ?? this.backgroundImagePath),
      );
}
