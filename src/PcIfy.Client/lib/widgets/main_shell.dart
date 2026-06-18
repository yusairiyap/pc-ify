import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/motion.dart';
import '../core/utils/shell_state.dart';
import '../providers/layout_providers.dart';

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
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: useExtended,
              selectedIndex: shell.currentIndex,
              onDestinationSelected: shell.goBranch,
              labelType: useExtended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: [
                for (final d in _kDestinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: shell),
          ],
        ),
      ),
    );
  }
}
