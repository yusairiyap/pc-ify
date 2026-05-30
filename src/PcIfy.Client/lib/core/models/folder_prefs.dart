class FolderPrefs {
  const FolderPrefs({
    this.backgroundImagePath,
    this.cropOffsetDx,
    this.cropOffsetDy,
    this.cropScale,
  });

  final String? backgroundImagePath;
  // Crop transform: pan offsets as pixel values, scale factor (1.0 = no zoom).
  // Null means no crop applied (BoxFit.cover default).
  final double? cropOffsetDx;
  final double? cropOffsetDy;
  final double? cropScale;

  bool get hasCrop =>
      cropOffsetDx != null || cropOffsetDy != null || cropScale != null;

  factory FolderPrefs.fromJson(Map<String, dynamic> json) => FolderPrefs(
        backgroundImagePath: json['backgroundImagePath'] as String?,
        cropOffsetDx: (json['cropOffsetDx'] as num?)?.toDouble(),
        cropOffsetDy: (json['cropOffsetDy'] as num?)?.toDouble(),
        cropScale: (json['cropScale'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'backgroundImagePath': backgroundImagePath,
        'cropOffsetDx': cropOffsetDx,
        'cropOffsetDy': cropOffsetDy,
        'cropScale': cropScale,
      };

  FolderPrefs copyWith({
    String? backgroundImagePath,
    double? cropOffsetDx,
    double? cropOffsetDy,
    double? cropScale,
    bool clearBackground = false,
    bool clearCrop = false,
  }) =>
      FolderPrefs(
        backgroundImagePath:
            clearBackground ? null : (backgroundImagePath ?? this.backgroundImagePath),
        cropOffsetDx: clearBackground || clearCrop ? null : (cropOffsetDx ?? this.cropOffsetDx),
        cropOffsetDy: clearBackground || clearCrop ? null : (cropOffsetDy ?? this.cropOffsetDy),
        cropScale: clearBackground || clearCrop ? null : (cropScale ?? this.cropScale),
      );
}
