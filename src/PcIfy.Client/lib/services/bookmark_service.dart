import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/bookmarked_folder.dart';

class BookmarkService {
  BookmarkService(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'bookmarks_json';

  List<BookmarkedFolder> getBookmarks() {
    final json = _prefs.getString(_key);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => BookmarkedFolder.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addBookmark(BookmarkedFolder bookmark) async {
    final list = getBookmarks();
    if (list.any((b) => b.path == bookmark.path)) return;
    list.add(bookmark);
    await _save(list);
  }

  Future<void> removeBookmark(String path) async {
    final list = getBookmarks()..removeWhere((b) => b.path == path);
    await _save(list);
  }

  Future<void> reorder(List<BookmarkedFolder> newOrder) => _save(newOrder);

  bool isBookmarked(String path) => getBookmarks().any((b) => b.path == path);

  Future<void> _save(List<BookmarkedFolder> list) =>
      _prefs.setString(_key, jsonEncode(list.map((b) => b.toJson()).toList()));
}
