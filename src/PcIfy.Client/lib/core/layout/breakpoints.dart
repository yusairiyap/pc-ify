import 'package:flutter/widgets.dart';

/// Material 3 window size classes, driven by the current width.
enum WindowSize { compact, medium, expanded }

/// Width-based responsive breakpoints. Mirrors the static-helper style of
/// [GridDensityHelper] and is the single place that owns the dp thresholds.
abstract final class Breakpoints {
  /// Phones in portrait are below this.
  static const double medium = 600;

  /// Tablets / large windows are at or above this.
  static const double expanded = 840;

  static WindowSize of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < medium) return WindowSize.compact;
    if (w < expanded) return WindowSize.medium;
    return WindowSize.expanded;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;

  static bool isAtLeastMedium(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;
}
