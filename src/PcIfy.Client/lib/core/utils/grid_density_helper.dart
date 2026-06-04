import 'package:flutter/material.dart' show IconData, Icons;

enum GridDensity { compact, normal, large }

abstract final class GridDensityHelper {
  static int getColumnCount(double widthDp, GridDensity density) {
    return switch (density) {
      GridDensity.compact => _columnsForWidth(widthDp, compact: true),
      GridDensity.normal => _columnsForWidth(widthDp, compact: false),
      GridDensity.large => _columnsForWidthLarge(widthDp),
    };
  }

  static int _columnsForWidth(double w, {required bool compact}) {
    if (compact) {
      if (w < 400) return 3;
      if (w < 600) return 4;
      if (w < 800) return 5;
      if (w < 1200) return 6;
      return 8;
    } else {
      if (w < 400) return 2;
      if (w < 600) return 3;
      if (w < 800) return 4;
      if (w < 1200) return 5;
      return 6;
    }
  }

  static int _columnsForWidthLarge(double w) {
    if (w < 400) return 1;
    if (w < 600) return 2;
    if (w < 800) return 3;
    if (w < 1200) return 4;
    return 5;
  }

  static String label(GridDensity density) => switch (density) {
        GridDensity.compact => 'Compact',
        GridDensity.normal => 'Normal',
        GridDensity.large => 'Large',
      };

  static GridDensity next(GridDensity density) => switch (density) {
        GridDensity.compact => GridDensity.normal,
        GridDensity.normal => GridDensity.large,
        GridDensity.large => GridDensity.compact,
      };

  static GridDensity fromString(String s) => GridDensity.values.firstWhere(
        (e) => e.name == s,
        orElse: () => GridDensity.normal,
      );

  static IconData icon(GridDensity density) => switch (density) {
        GridDensity.compact => Icons.grid_on,
        GridDensity.normal => Icons.grid_view,
        GridDensity.large => Icons.view_module,
      };
}
