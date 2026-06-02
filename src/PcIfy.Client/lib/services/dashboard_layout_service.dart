import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/dashboard_models.dart';

class DashboardLayoutService {
  DashboardLayoutService(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'dashboard_layout_v1';

  DashboardLayout getLayout() {
    final json = _prefs.getString(_key);
    if (json == null) return DashboardLayout.defaultLayout();
    try {
      final layout = DashboardLayout.fromJson(jsonDecode(json) as Map<String, dynamic>);
      // Drop sections that have no items after filtering removed widget types
      final sections = layout.sections
          .where((s) => s.isBookmarks || s.items.isNotEmpty)
          .toList();
      if (sections.isEmpty) return DashboardLayout.defaultLayout();
      return DashboardLayout(sections: sections);
    } catch (_) {
      return DashboardLayout.defaultLayout();
    }
  }

  Future<void> saveLayout(DashboardLayout layout) =>
      _prefs.setString(_key, jsonEncode(layout.toJson()));

  Future<void> resetToDefault() => saveLayout(DashboardLayout.defaultLayout());
}
