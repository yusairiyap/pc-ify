import 'package:flutter/widgets.dart';

/// Centralized corner-radius tokens for the expressive shape language.
abstract final class AppShapes {
  /// Resting corner radius for cards / surfaces.
  static const double card = 16.0;

  /// Slightly larger radius used as a press / morph target.
  static const double cardPressed = 22.0;

  /// Tighter corner when an item is selected (gives a subtle shape morph).
  static const double selected = 8.0;

  static final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(card),
  );
}
