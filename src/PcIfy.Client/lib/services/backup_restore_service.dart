import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/bookmarked_folder.dart';
import '../core/models/folder_prefs.dart';
import 'bookmark_service.dart';
import 'folder_prefs_service.dart';

class BackupData {
  const BackupData({
    required this.version,
    required this.createdAt,
    this.bookmarks,
    this.bookmarkFolderPrefs,
    this.otherFolderPrefs,
    this.settings,
  });

  final int version;
  final DateTime createdAt;
  final List<BookmarkedFolder>? bookmarks;

  /// Folder prefs keyed by SHA-256 hash of the bookmarked folder path.
  final Map<String, Map<String, dynamic>>? bookmarkFolderPrefs;

  /// Folder prefs (home screen, non-bookmarked folders) keyed by hash.
  final Map<String, Map<String, dynamic>>? otherFolderPrefs;

  final Map<String, dynamic>? settings;

  bool get hasBookmarks => bookmarks != null;
  bool get hasBookmarkFolderPrefs =>
      bookmarkFolderPrefs != null && bookmarkFolderPrefs!.isNotEmpty;
  bool get hasOtherFolderPrefs =>
      otherFolderPrefs != null && otherFolderPrefs!.isNotEmpty;
  bool get hasSettings => settings != null && settings!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'version': version,
        'createdAt': createdAt.toIso8601String(),
        if (bookmarks != null)
          'bookmarks': bookmarks!.map((b) => b.toJson()).toList(),
        if (bookmarkFolderPrefs != null)
          'bookmarkFolderPrefs': bookmarkFolderPrefs,
        if (otherFolderPrefs != null) 'otherFolderPrefs': otherFolderPrefs,
        if (settings != null) 'settings': settings,
      };

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final bookmarksList = json['bookmarks'] as List<dynamic>?;
    final bookmarkPrefsMap =
        json['bookmarkFolderPrefs'] as Map<String, dynamic>?;
    final otherPrefsMap = json['otherFolderPrefs'] as Map<String, dynamic>?;
    final settingsMap = json['settings'] as Map<String, dynamic>?;

    return BackupData(
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      bookmarks: bookmarksList
          ?.map((e) => BookmarkedFolder.fromJson(e as Map<String, dynamic>))
          .toList(),
      bookmarkFolderPrefs: bookmarkPrefsMap?.map(
        (k, v) => MapEntry(k, v as Map<String, dynamic>),
      ),
      otherFolderPrefs: otherPrefsMap?.map(
        (k, v) => MapEntry(k, v as Map<String, dynamic>),
      ),
      settings: settingsMap,
    );
  }
}

class BackupRestoreService {
  BackupRestoreService(
      this._prefs, this._bookmarkService, this._folderPrefsService);

  final SharedPreferences _prefs;
  final BookmarkService _bookmarkService;
  final FolderPrefsService _folderPrefsService;

  static const _settingsKeys = [
    'theme_mode',
    'accent_color',
    'grid_density',
    'always_external_player',
    'video_fit_mode',
    'video_auto_repeat',
  ];

  String _hashPath(String path) =>
      sha256.convert(utf8.encode(path)).toString();

  Future<BackupData> collectBackup({
    bool includeBookmarks = true,
    bool includeBookmarkFolderPrefs = true,
    bool includeOtherFolderPrefs = true,
    bool includeSettings = true,
  }) async {
    final currentBookmarks = _bookmarkService.getBookmarks();
    final bookmarkHashes = {
      for (final b in currentBookmarks) _hashPath(b.path): b.path,
    };

    List<BookmarkedFolder>? bookmarks;
    Map<String, Map<String, dynamic>>? bookmarkFolderPrefs;
    Map<String, Map<String, dynamic>>? otherFolderPrefs;
    Map<String, dynamic>? settings;

    if (includeBookmarks) bookmarks = currentBookmarks;

    if (includeBookmarkFolderPrefs || includeOtherFolderPrefs) {
      final allPrefs = await _folderPrefsService.getAllPrefs();

      if (includeBookmarkFolderPrefs) {
        bookmarkFolderPrefs = {
          for (final hash in bookmarkHashes.keys)
            if (allPrefs.containsKey(hash)) hash: allPrefs[hash]!.toJson(),
        };
      }

      if (includeOtherFolderPrefs) {
        otherFolderPrefs = {
          for (final entry in allPrefs.entries)
            if (!bookmarkHashes.containsKey(entry.key))
              entry.key: entry.value.toJson(),
        };
      }
    }

    if (includeSettings) {
      settings = {
        for (final key in _settingsKeys)
          if (_prefs.get(key) != null) key: _prefs.get(key)!,
      };
    }

    return BackupData(
      version: 1,
      createdAt: DateTime.now(),
      bookmarks: bookmarks,
      bookmarkFolderPrefs: bookmarkFolderPrefs,
      otherFolderPrefs: otherFolderPrefs,
      settings: settings,
    );
  }

  Future<String?> exportToFile(BackupData data) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data.toJson())));
    final now = DateTime.now();
    final fileName =
        'pcify_backup_${now.year}${_p(now.month)}${_p(now.day)}_${_p(now.hour)}${_p(now.minute)}.json';

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save backup',
      fileName: fileName,
      // bytes is used by Android/Web; desktop only returns the path.
      bytes: bytes,
    );
    if (path == null) return null;

    // On desktop, saveFile only opens the dialog — write the bytes ourselves.
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await File(path).writeAsBytes(bytes);
    }

    return path;
  }

  Future<BackupData?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) return null;

    try {
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return BackupData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> restoreBackup(
    BackupData data, {
    bool restoreBookmarks = true,
    bool restoreBookmarkFolderPrefs = true,
    bool restoreOtherFolderPrefs = true,
    bool restoreSettings = true,
  }) async {
    if (restoreBookmarks && data.bookmarks != null) {
      for (final b in data.bookmarks!) {
        await _bookmarkService.addBookmark(b);
      }
    }

    if (restoreBookmarkFolderPrefs && data.bookmarkFolderPrefs != null) {
      for (final entry in data.bookmarkFolderPrefs!.entries) {
        await _folderPrefsService.savePrefsForHash(
          entry.key,
          FolderPrefs.fromJson(entry.value),
        );
      }
    }

    if (restoreOtherFolderPrefs && data.otherFolderPrefs != null) {
      for (final entry in data.otherFolderPrefs!.entries) {
        await _folderPrefsService.savePrefsForHash(
          entry.key,
          FolderPrefs.fromJson(entry.value),
        );
      }
    }

    if (restoreSettings && data.settings != null) {
      for (final entry in data.settings!.entries) {
        final v = entry.value;
        if (v is String) {
          await _prefs.setString(entry.key, v);
        } else if (v is bool) {
          await _prefs.setBool(entry.key, v);
        } else if (v is int) {
          await _prefs.setInt(entry.key, v);
        } else if (v is double) {
          await _prefs.setDouble(entry.key, v);
        }
      }
    }
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}
