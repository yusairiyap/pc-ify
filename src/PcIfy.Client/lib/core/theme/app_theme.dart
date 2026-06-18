import 'package:flutter/material.dart';

import 'shapes.dart';

/// Single source of truth for the app's [ThemeData]. Both `theme` and
/// `darkTheme` in `app.dart` are built from this factory so light/dark stay in
/// lockstep, and so the expressive motion / shape / surface tokens are applied
/// in exactly one place.
ThemeData buildAppTheme(ColorScheme scheme) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);

  const transitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    },
  );

  return base.copyWith(
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: transitions,
    cardTheme: base.cardTheme.copyWith(
      shape: AppShapes.cardShape,
      clipBehavior: Clip.antiAlias,
    ),
    appBarTheme: base.appBarTheme.copyWith(centerTitle: false),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    navigationRailTheme: base.navigationRailTheme.copyWith(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
    ),
  );
}
