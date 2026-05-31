import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImportPreview {
  const ImportPreview({
    required this.hasAppSettings,
    required this.hasBookmarks,
    required this.folderBackgroundCount,
    required this.thumbnailCacheFileCount,
  });

  final bool hasAppSettings;
  final bool hasBookmarks;
  final int folderBackgroundCount;
  final int thumbnailCacheFileCount;
}

class ImportExportService {
  ImportExportService(this._prefs);

  final SharedPreferences _prefs;

  static const Map<String, String> _settingsKeyTypes = {
    'theme_mode': 'String',
    'accent_color': 'Int',
    'grid_density': 'String',
    'always_external_player': 'Bool',
    'video_fit_mode': 'String',
    'video_auto_repeat': 'Bool',
  };

  Future<File> exportToZip({
    required bool appSettings,
    required bool bookmarks,
    required bool folderBackgrounds,
    required bool thumbnailCache,
  }) async {
    final archive = Archive();

    if (appSettings) {
      final map = <String, dynamic>{};
      for (final entry in _settingsKeyTypes.entries) {
        dynamic value;
        switch (entry.value) {
          case 'String':
            value = _prefs.getString(entry.key);
          case 'Int':
            value = _prefs.getInt(entry.key);
          case 'Bool':
            value = _prefs.getBool(entry.key);
        }
        if (value != null) map[entry.key] = value;
      }
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(map)));
      archive.addFile(ArchiveFile('settings.json', bytes.length, bytes));
    }

    if (bookmarks) {
      final raw = _prefs.getString('bookmarks_json') ?? '[]';
      final bytes = Uint8List.fromList(utf8.encode(raw));
      archive.addFile(ArchiveFile('bookmarks.json', bytes.length, bytes));
    }

    if (folderBackgrounds) {
      final appDir = await getApplicationDocumentsDirectory();
      final folderPrefsDir = Directory('${appDir.path}/folderprefs');
      if (await folderPrefsDir.exists()) {
        for (final entity in folderPrefsDir.listSync()) {
          if (entity is File && entity.path.endsWith('.json')) {
            final bytes = await entity.readAsBytes();
            final name = entity.uri.pathSegments.last;
            archive.addFile(ArchiveFile('folder_prefs/$name', bytes.length, bytes));
          }
        }
      }
    }

    if (thumbnailCache) {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/libCachedImageData');
      if (await cacheDir.exists()) {
        for (final entity in cacheDir.listSync(recursive: true)) {
          if (entity is File) {
            final bytes = await entity.readAsBytes();
            final relative = entity.path.substring(tempDir.path.length + 1);
            archive.addFile(ArchiveFile('thumbnails/$relative', bytes.length, bytes));
          }
        }
      }
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw Exception('Failed to encode ZIP');

    final downloadsDir = await _getDownloadsDir();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final file = File('${downloadsDir.path}/pcify_export_$date.zip');
    await file.writeAsBytes(encoded);
    return file;
  }

  Future<ImportPreview> inspectZip(String path) async {
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    bool hasSettings = false;
    bool hasBookmarks = false;
    int folderBgCount = 0;
    int thumbCount = 0;

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name;
      if (name == 'settings.json') {
        hasSettings = true;
      } else if (name == 'bookmarks.json') {
        hasBookmarks = true;
      } else if (name.startsWith('folder_prefs/') && name.endsWith('.json')) {
        folderBgCount++;
      } else if (name.startsWith('thumbnails/')) {
        thumbCount++;
      }
    }

    return ImportPreview(
      hasAppSettings: hasSettings,
      hasBookmarks: hasBookmarks,
      folderBackgroundCount: folderBgCount,
      thumbnailCacheFileCount: thumbCount,
    );
  }

  Future<void> importFromZip({
    required String zipPath,
    required bool appSettings,
    required bool bookmarks,
    required bool folderBackgrounds,
    required bool thumbnailCache,
  }) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    if (appSettings) {
      final settingsFile = archive.files
          .where((f) => f.isFile && f.name == 'settings.json')
          .firstOrNull;
      if (settingsFile != null) {
        final json = jsonDecode(utf8.decode(settingsFile.content as List<int>))
            as Map<String, dynamic>;
        for (final entry in json.entries) {
          final type = _settingsKeyTypes[entry.key];
          if (type == null) continue;
          switch (type) {
            case 'String':
              await _prefs.setString(entry.key, entry.value as String);
            case 'Int':
              await _prefs.setInt(entry.key, (entry.value as num).toInt());
            case 'Bool':
              await _prefs.setBool(entry.key, entry.value as bool);
          }
        }
      }
    }

    if (bookmarks) {
      final bookmarksFile = archive.files
          .where((f) => f.isFile && f.name == 'bookmarks.json')
          .firstOrNull;
      if (bookmarksFile != null) {
        final content = utf8.decode(bookmarksFile.content as List<int>);
        await _prefs.setString('bookmarks_json', content);
      }
    }

    if (folderBackgrounds) {
      final appDir = await getApplicationDocumentsDirectory();
      final folderPrefsDir = Directory('${appDir.path}/folderprefs');
      if (!await folderPrefsDir.exists()) {
        await folderPrefsDir.create(recursive: true);
      }
      for (final file in archive.files) {
        if (!file.isFile) continue;
        if (!file.name.startsWith('folder_prefs/') ||
            !file.name.endsWith('.json')) continue;
        final filename = file.name.split('/').last;
        await File('${folderPrefsDir.path}/$filename')
            .writeAsBytes(file.content as List<int>);
      }
    }

    if (thumbnailCache) {
      final tempDir = await getTemporaryDirectory();
      for (final file in archive.files) {
        if (!file.isFile) continue;
        if (!file.name.startsWith('thumbnails/')) continue;
        final relative = file.name.substring('thumbnails/'.length);
        if (relative.isEmpty) continue;
        final outFile = File('${tempDir.path}/$relative');
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }
  }

  Future<Directory> _getDownloadsDir() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    }
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/Downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
