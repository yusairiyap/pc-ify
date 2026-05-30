enum FileType { unknown, folder, video, image, audio, document, archive }

class FileEntry {
  const FileEntry({
    required this.name,
    required this.path,
    required this.type,
    required this.sizeBytes,
    required this.lastModified,
    required this.hasThumbnail,
  });

  final String name;
  final String path;
  final FileType type;
  final int sizeBytes;
  final DateTime lastModified;
  final bool hasThumbnail;

  factory FileEntry.fromJson(Map<String, dynamic> json) => FileEntry(
        name: json['name'] as String,
        path: json['path'] as String,
        type: FileType.values.firstWhere(
          (e) => e.name == (json['type'] as String).toLowerCase(),
          orElse: () => FileType.unknown,
        ),
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        lastModified: DateTime.tryParse(json['lastModified'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        hasThumbnail: json['hasThumbnail'] as bool? ?? false,
      );
}
