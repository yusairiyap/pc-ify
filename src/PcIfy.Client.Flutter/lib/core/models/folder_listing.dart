import 'file_entry.dart';

class FolderListing {
  const FolderListing({
    required this.path,
    required this.parentPath,
    required this.displayName,
    required this.entries,
  });

  final String path;
  final String? parentPath;
  final String displayName;
  final List<FileEntry> entries;

  factory FolderListing.fromJson(Map<String, dynamic> json) => FolderListing(
        path: json['path'] as String,
        parentPath: json['parentPath'] as String?,
        displayName: json['displayName'] as String,
        entries: (json['entries'] as List<dynamic>)
            .map((e) => FileEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
