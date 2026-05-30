class BookmarkedFolder {
  const BookmarkedFolder({
    required this.path,
    required this.displayName,
    this.coverImagePath,
  });

  final String path;
  final String displayName;
  final String? coverImagePath;

  factory BookmarkedFolder.fromJson(Map<String, dynamic> json) =>
      BookmarkedFolder(
        path: json['path'] as String,
        displayName: json['displayName'] as String,
        coverImagePath: json['coverImagePath'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'path': path,
        'displayName': displayName,
        'coverImagePath': coverImagePath,
      };
}
