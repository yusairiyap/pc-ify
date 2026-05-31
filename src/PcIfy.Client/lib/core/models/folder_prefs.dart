class FolderPrefs {
  const FolderPrefs({
    this.backgroundImagePath,
    this.cropOffsetDx,
    this.cropOffsetDy,
    this.cropScale,
    this.backgroundVideoPath,
    this.videoLoopStartMs,
    this.videoLoopEndMs,
  });

  final String? backgroundImagePath;
  // Crop transform: pan offsets as pixel values, scale factor (1.0 = no zoom).
  // Null means no crop applied (BoxFit.cover default).
  final double? cropOffsetDx;
  final double? cropOffsetDy;
  final double? cropScale;

  final String? backgroundVideoPath;
  final int? videoLoopStartMs;
  final int? videoLoopEndMs;

  bool get hasCrop =>
      cropOffsetDx != null || cropOffsetDy != null || cropScale != null;

  bool get hasBackground =>
      backgroundImagePath != null || backgroundVideoPath != null;

  bool get isVideoBackground => backgroundVideoPath != null;

  factory FolderPrefs.fromJson(Map<String, dynamic> json) => FolderPrefs(
        backgroundImagePath: json['backgroundImagePath'] as String?,
        cropOffsetDx: (json['cropOffsetDx'] as num?)?.toDouble(),
        cropOffsetDy: (json['cropOffsetDy'] as num?)?.toDouble(),
        cropScale: (json['cropScale'] as num?)?.toDouble(),
        backgroundVideoPath: json['backgroundVideoPath'] as String?,
        videoLoopStartMs: (json['videoLoopStartMs'] as num?)?.toInt(),
        videoLoopEndMs: (json['videoLoopEndMs'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'backgroundImagePath': backgroundImagePath,
        'cropOffsetDx': cropOffsetDx,
        'cropOffsetDy': cropOffsetDy,
        'cropScale': cropScale,
        'backgroundVideoPath': backgroundVideoPath,
        'videoLoopStartMs': videoLoopStartMs,
        'videoLoopEndMs': videoLoopEndMs,
      };

  FolderPrefs copyWith({
    String? backgroundImagePath,
    double? cropOffsetDx,
    double? cropOffsetDy,
    double? cropScale,
    String? backgroundVideoPath,
    int? videoLoopStartMs,
    int? videoLoopEndMs,
    bool clearBackground = false,
    bool clearCrop = false,
  }) =>
      FolderPrefs(
        backgroundImagePath:
            clearBackground ? null : (backgroundImagePath ?? this.backgroundImagePath),
        cropOffsetDx: clearBackground || clearCrop ? null : (cropOffsetDx ?? this.cropOffsetDx),
        cropOffsetDy: clearBackground || clearCrop ? null : (cropOffsetDy ?? this.cropOffsetDy),
        cropScale: clearBackground || clearCrop ? null : (cropScale ?? this.cropScale),
        backgroundVideoPath:
            clearBackground ? null : (backgroundVideoPath ?? this.backgroundVideoPath),
        videoLoopStartMs:
            clearBackground ? null : (videoLoopStartMs ?? this.videoLoopStartMs),
        videoLoopEndMs:
            clearBackground ? null : (videoLoopEndMs ?? this.videoLoopEndMs),
      );
}
