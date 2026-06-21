import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/layout/breakpoints.dart';
import '../core/models/folder_prefs.dart';
import 'services_providers.dart';

/// The folder background currently being shown by the Browse screen, hoisted up
/// so [MainShell] can paint it full-width behind a transparent navigation rail
/// on wide layouts. Null when there is no background or the layout is compact.
class WindowBackground {
  const WindowBackground({this.imageUri, this.videoUri, required this.prefs});
  final String? imageUri;
  final String? videoUri;
  final FolderPrefs prefs;

  bool get isEmpty => imageUri == null && videoUri == null;
}

final browseBackgroundProvider =
    StateProvider<WindowBackground?>((ref) => null);

/// How the tablet / wide layout (navigation rail + master-detail browser) is
/// chosen.
enum TabletLayoutMode { auto, on, off }

const _tabletLayoutKey = 'tablet_layout_mode';

/// Seeded from SharedPreferences (same pattern as `statusPollIntervalProvider`).
/// The settings screen flips `.state` and persists the value.
final tabletLayoutModeProvider = StateProvider<TabletLayoutMode>((ref) {
  return switch (ref.read(sharedPrefsProvider).getString(_tabletLayoutKey)) {
    'on' => TabletLayoutMode.on,
    'off' => TabletLayoutMode.off,
    _ => TabletLayoutMode.auto,
  };
});

String tabletLayoutModeToString(TabletLayoutMode mode) => switch (mode) {
      TabletLayoutMode.on => 'on',
      TabletLayoutMode.off => 'off',
      TabletLayoutMode.auto => 'auto',
    };

/// Single source of truth for whether wide/adaptive layouts (navigation rail,
/// master-detail browser, multi-column settings/home) should be shown.
///
/// `on` is clamped to at least the medium breakpoint so forcing it on a phone
/// never produces a cramped rail + detail pane.
bool useExpandedLayout(BuildContext context, TabletLayoutMode mode) =>
    switch (mode) {
      TabletLayoutMode.on => Breakpoints.isAtLeastMedium(context),
      TabletLayoutMode.off => false,
      TabletLayoutMode.auto => Breakpoints.isExpanded(context),
    };
