import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dashboard_providers.dart';
import 'dashboard_edit_view.dart';
import 'dashboard_section_view.dart';

class DashboardBody extends ConsumerWidget {
  const DashboardBody({super.key, required this.hasBg});
  final bool hasBg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(dashboardEditModeProvider);
    final layout = ref.watch(dashboardLayoutProvider);

    if (editMode) {
      return DashboardEditView(layout: layout, hasBg: hasBg);
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(controlStatusProvider);
        ref.invalidate(serverInfoProvider);
        // Await the new load (up to 5 s) so the indicator stays visible until
        // data arrives, not just until a fixed timer fires.
        try {
          await ref
              .read(controlStatusProvider.future)
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
      },
      child: CustomScrollView(
        // Required so the pull gesture fires even when content fits the viewport.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          for (final section in layout.sections)
            SliverToBoxAdapter(
              child: DashboardSectionView(section: section, hasBg: hasBg),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}
