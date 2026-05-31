import 'dart:io';
import 'package:path/path.dart' as p;
import '../core/constants/media_types.dart';
import '../core/models/app_settings.dart';
import '../core/utils/file_type_helper.dart';
import '../core/utils/path_sanitizer.dart';

class FileEntry {
  final String name;
  final String path;
  final FileType type;
  final int sizeBytes;
  final DateTime lastModified;
  final bool hasThumbnail;

  const FileEntry({
    required this.name,
    required this.path,
    required this.type,
    required this.sizeBytes,
    required this.lastModified,
    required this.hasThumbnail,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'type': type.name,
        'sizeBytes': sizeBytes,
        'lastModified': lastModified.toIso8601String(),
        'hasThumbnail': hasThumbnail,
      };
}

class FolderListing {
  final String path;
  final String? parentPath;
  final String displayName;
  final List<FileEntry> entries;

  const FolderListing({
    required this.path,
    this.parentPath,
    required this.displayName,
    required this.entries,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'parentPath': parentPath,
        'displayName': displayName,
        'entries': entries.map((e) => e.toJson()).toList(),
      };
}

class RootEntry {
  final String path;
  final String displayName;

  const RootEntry({required this.path, required this.displayName});

  Map<String, dynamic> toJson() => {'path': path, 'displayName': displayName};
}

class FileService {
  final AppSettings settings;

  FileService(this.settings);

  List<RootEntry> getRoots() => settings.sourceDirectories
      .map((d) => RootEntry(path: d, displayName: p.basename(d)))
      .toList();

  bool isPathAllowed(String path) =>
      PathSanitizer.isPathAllowed(path, settings.sourceDirectories);

  Future<FolderListing?> getFolderListing(String dirPath) async {
    final sanitized = PathSanitizer.sanitize(dirPath, settings.sourceDirectories);
    if (sanitized == null) return null;

    final dir = Directory(sanitized);
    if (!await dir.exists()) return null;

    final allEntries = await dir.list().toList();

    final dirs = allEntries.whereType<Directory>().toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    final files = allEntries.whereType<File>().toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    final entries = <FileEntry>[];
    for (final d in dirs) {
      entries.add(FileEntry(
        name: p.basename(d.path),
        path: d.path,
        type: FileType.folder,
        sizeBytes: 0,
        lastModified: (await d.stat()).modified,
        hasThumbnail: false,
      ));
    }
    for (final f in files) {
      final ext = p.extension(f.path);
      final type = FileTypeHelper.fromExtension(ext);
      final stat = await f.stat();
      entries.add(FileEntry(
        name: p.basename(f.path),
        path: f.path,
        type: type,
        sizeBytes: stat.size,
        lastModified: stat.modified,
        hasThumbnail: MediaTypes.isThumbnailable(ext.replaceFirst('.', '')),
      ));
    }

    String? parentPath;
    final parentDir = dir.parent;
    if (PathSanitizer.isPathAllowed(
        parentDir.path, settings.sourceDirectories)) {
      parentPath = parentDir.path;
    }

    return FolderListing(
      path: sanitized,
      parentPath: parentPath,
      displayName: p.basename(sanitized),
      entries: entries,
    );
  }

  /// Opens a stream for [filePath]. Returns null if path is not allowed.
  /// Supports range requests via [start] / [end] byte offsets.
  Stream<List<int>>? openStream(
    String filePath, {
    int? start,
    int? end,
  }) {
    final sanitized = PathSanitizer.sanitize(filePath, settings.sourceDirectories);
    if (sanitized == null) return null;

    final file = File(sanitized);
    if (!file.existsSync()) return null;

    return file.openRead(start, end != null ? end + 1 : null);
  }

  Future<int?> getFileSize(String filePath) async {
    final sanitized =
        PathSanitizer.sanitize(filePath, settings.sourceDirectories);
    if (sanitized == null) return null;
    final file = File(sanitized);
    if (!await file.exists()) return null;
    return (await file.stat()).size;
  }

  String getMimeType(String filePath) {
    final ext = p.extension(filePath).replaceFirst('.', '');
    return MediaTypes.getMimeType(ext);
  }
}
