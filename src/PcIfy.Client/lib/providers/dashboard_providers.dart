import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/bookmarked_folder.dart';
import '../core/models/control_status.dart';
import '../core/models/dashboard_models.dart';
import '../core/models/file_entry.dart';
import 'services_providers.dart';

// ── Layout ────────────────────────────────────────────────────────────────────

final dashboardLayoutProvider =
    NotifierProvider<DashboardLayoutNotifier, DashboardLayout>(
        DashboardLayoutNotifier.new);

class DashboardLayoutNotifier extends Notifier<DashboardLayout> {
  @override
  DashboardLayout build() =>
      ref.read(dashboardLayoutServiceProvider).getLayout();

  Future<void> update(DashboardLayout layout) async {
    await ref.read(dashboardLayoutServiceProvider).saveLayout(layout);
    state = layout;
  }

  Future<void> resetToDefault() async {
    final layout = DashboardLayout.defaultLayout();
    await ref.read(dashboardLayoutServiceProvider).saveLayout(layout);
    state = layout;
  }
}

// ── Bookmarks (moved from home_screen.dart) ────────────────────────────────

final bookmarksProvider = Provider<List<BookmarkedFolder>>((ref) {
  return ref.watch(bookmarkServiceProvider).getBookmarks();
});

final bookmarkThumbnailsProvider =
    FutureProvider.autoDispose.family<List<String>, String>(
  (ref, folderPath) async {
    final api = ref.watch(apiServiceProvider);
    final listing = await api.getFolderListing(folderPath);
    if (listing == null) return [];

    final mediaFiles = listing.entries
        .where((e) =>
            (e.type == FileType.image || e.type == FileType.video) &&
            e.hasThumbnail)
        .take(3)
        .toList();

    return Future.wait(
      mediaFiles.map(
        (e) => api.buildThumbnailUriWithToken(e.path, size: 'small'),
      ),
    );
  },
);

// ── Control status (5-second poll) ────────────────────────────────────────────

final controlStatusProvider = AsyncNotifierProvider.autoDispose<
    ControlStatusNotifier, ControlStatus>(ControlStatusNotifier.new);

class ControlStatusNotifier extends AutoDisposeAsyncNotifier<ControlStatus> {
  Timer? _timer;

  @override
  Future<ControlStatus> build() async {
    ref.onDispose(() => _timer?.cancel());
    final status = await _fetch();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    return status;
  }

  Future<ControlStatus> _fetch() async {
    return await ref.read(apiServiceProvider).getControlStatus() ??
        ControlStatus.unavailable();
  }

  Future<void> _refresh() async {
    final fresh = await _fetch();
    state = AsyncData(fresh);
  }
}

// ── Edit mode ─────────────────────────────────────────────────────────────────

final dashboardEditModeProvider = StateProvider<bool>((ref) => false);
