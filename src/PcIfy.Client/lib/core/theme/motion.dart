import 'package:flutter/animation.dart';

/// Centralized motion tokens — durations and easing curves shared by route
/// transitions, the tab container, and in-widget animations so the app has a
/// single, consistent "feel". Modelled on Material 3's emphasized motion, plus
/// a gentle spring overshoot built from a stable cubic (no physics package).
abstract final class AppMotion {
  // Durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 300);
  static const Duration emphasized = Duration(milliseconds: 450);

  // Easing curves
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve standardEasing = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Gentle back-out overshoot — used for selection / shape-morph so corners
  /// and surfaces settle with a small spring instead of snapping.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1.0);
}
