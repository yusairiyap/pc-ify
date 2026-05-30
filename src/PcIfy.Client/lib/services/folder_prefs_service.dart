import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../core/models/folder_prefs.dart';

class FolderPrefsService {
  Directory? _dir;

  Future<Directory> _getDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/folderprefs');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  String _key(String folderPath) {
    final bytes = utf8.encode(folderPath);
    return sha256.convert(bytes).toString();
  }

  Future<FolderPrefs> getPrefs(String folderPath) async {
    final dir = await _getDir();
    final file = File('${dir.path}/${_key(folderPath)}.json');
    if (!await file.exists()) return const FolderPrefs();
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return FolderPrefs.fromJson(json);
    } catch (_) {
      return const FolderPrefs();
    }
  }

  Future<void> savePrefs(String folderPath, FolderPrefs prefs) async {
    final dir = await _getDir();
    final file = File('${dir.path}/${_key(folderPath)}.json');
    await file.writeAsString(jsonEncode(prefs.toJson()));
  }
}
