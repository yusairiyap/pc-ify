import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/motion.dart';
import '../core/utils/shell_state.dart';
import '../providers/layout_providers.dart';
import 'folder_background_image.dart';
import 'video_background_player.dart';

class AnimatedTabContainer extends StatefulWidget {
  const AnimatedTabContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<AnimatedTabContainer> createState() => _AnimatedTabContainerState();
}

class _AnimatedTabContainerState extends State<AnimatedTabContainer> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.currentIndex);
    ShellState.currentTabIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(AnimatedTabContainer old) {
    super.didUpdateWidget(old);
    if (widget.currentIndex != old.currentIndex) {
      ShellState.currentTabIndex = widget.currentIndex;
      _controller.animateToPage(
        widget.currentIndex,
        duration: AppMotion.standard,
        curve: AppMotion.standardEasing,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _controller,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final child in widget.children) _KeepAlivePage(child: child),
      ],
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});
  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Top-level navigation destinations, shared between the bottom bar (compact)
/// and the navigation rail (expanded) so they never drift apart.
typedef _Destination = ({IconData icon, IconData selected, String label});

const List<_Destination> _kDestinations = [
  (icon: Icons.home_outlined, selected: Icons.home, label: 'Home'),
  (icon: Icons.folder_outlined, selected: Icons.folder, label: 'Browse'),
  (icon: Icons.settings_outlined, selected: Icons.settings, label: 'Settings'),
];

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(tabletLayoutModeProvider);
    final expanded = useExpandedLayout(context, mode);

    if (!expanded) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: shell.goBranch,
          destinations: [
            for (final d in _kDestinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selected),
                label: d.label,
              ),
          ],
        ),
      );
    }

    // Extend the rail (icon + label side by side) on very wide windows.
    final useExtended = MediaQuery.sizeOf(context).width >= 1240;

    // When the Browse tab has a folder background, paint it full-width behind a
    // transparent rail (the Browse screen renders transparent in this case).
    final bg = ref.watch(browseBackgroundProvider);
    final showBg =
        shell.currentIndex == 1 && bg != null && !bg.isEmpty;

    final rail = NavigationRail(
      extended: useExtended,
      backgroundColor: showBg ? Colors.transparent : null,
      selectedIndex: shell.currentIndex,
      onDestinationSelected: shell.goBranch,
      labelType: useExtended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      indicatorColor: showBg ? Colors.white24 : null,
      selectedIconTheme: showBg ? const IconThemeData(color: Colors.white) : null,
      unselectedIconTheme:
          showBg ? const IconThemeData(color: Colors.white70) : null,
      selectedLabelTextStyle:
          showBg ? const TextStyle(color: Colors.white) : null,
      unselectedLabelTextStyle:
          showBg ? const TextStyle(color: Colors.white70) : null,
      destinations: [
        for (final d in _kDestinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selected),
            label: Text(d.label),
          ),
      ],
    );

    return Scaffold(
      body: Stack(
        children: [
          if (showBg) Positioned.fill(child: _BackgroundLayer(bg)),
          SafeArea(
            child: Row(
              children: [
                rail,
                VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: showBg ? Colors.transparent : null),
                Expanded(child: shell),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-bleed folder background (image or video) with a dark scrim — painted by
/// [MainShell] behind a transparent rail so it spans the whole window.
class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer(this.bg);
  final WindowBackground bg;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bg.videoUri != null)
          VideoBackgroundPlayer(videoUri: bg.videoUri!, prefs: bg.prefs)
        else
          FolderBackgroundImage(imageUri: bg.imageUri!, prefs: bg.prefs),
        DecoratedBox(
          decoration:
              BoxDecoration(color: Colors.black.withValues(alpha: 0.35)),
        ),
      ],
    );
  }
}
