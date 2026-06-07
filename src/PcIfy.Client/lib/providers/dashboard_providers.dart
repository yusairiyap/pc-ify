import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/bookmarked_folder.dart';
import '../core/models/control_status.dart';
import '../core/models/dashboard_models.dart';
import '../core/models/file_entry.dart';
import '../core/models/server_info.dart';
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
        (e) => api.buildThumbnailUriWithToken(e.path, quality: 25),
      ),
    );
  },
);

// ── Control status (configurable poll) ────────────────────────────────────────

final controlStatusProvider = AsyncNotifierProvider.autoDispose<
    ControlStatusNotifier, ControlStatus>(ControlStatusNotifier.new);

class ControlStatusNotifier extends AutoDisposeAsyncNotifier<ControlStatus> {
  Timer? _timer;

  @override
  Future<ControlStatus> build() async {
    final intervalSecs = ref.watch(dashboardPollIntervalProvider);
    ref.onDispose(() => _timer?.cancel());
    // Start polling before the first await so the timer is registered even
    // if the initial fetch throws (server unreachable on startup).
    _timer = Timer.periodic(Duration(seconds: intervalSecs), (_) => _refresh());
    return _fetch();
  }

  Future<ControlStatus> _fetch() async {
    final status = await ref.read(apiServiceProvider).getControlStatus();
    // Null means the HTTP request failed — propagate as an error so the
    // Server Info card shows "Disconnected" instead of "Connected".
    if (status == null) throw Exception('Cannot reach server');
    return status;
  }

  Future<void> _refresh() async {
    try {
      state = AsyncData(await _fetch());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ── Server info (30-second poll) ──────────────────────────────────────────────

final serverInfoProvider = AsyncNotifierProvider.autoDispose<
    _ServerInfoNotifier, ServerInfo?>(_ServerInfoNotifier.new);

class _ServerInfoNotifier extends AutoDisposeAsyncNotifier<ServerInfo?> {
  Timer? _timer;

  @override
  Future<ServerInfo?> build() async {
    ref.onDispose(() => _timer?.cancel());
    final info = await _fetch();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    return info;
  }

  Future<ServerInfo?> _fetch() =>
      ref.read(apiServiceProvider).getServerInfo();

  Future<void> _refresh() async {
    final fresh = await _fetch();
    state = AsyncData(fresh);
  }
}

// ── Edit mode ─────────────────────────────────────────────────────────────────

final dashboardEditModeProvider = StateProvider<bool>((ref) => false);

// ── Clipboard status (configurable poll) ─────────────────────────────────────

final serverClipboardProvider = AsyncNotifierProvider.autoDispose<
    ServerClipboardNotifier, PcClipboardStatus>(ServerClipboardNotifier.new);

class ServerClipboardNotifier extends AutoDisposeAsyncNotifier<PcClipboardStatus> {
  Timer? _timer;

  @override
  Future<PcClipboardStatus> build() async {
    final intervalSecs = ref.watch(dashboardPollIntervalProvider);
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(Duration(seconds: intervalSecs), (_) => _refresh());
    return _fetch();
  }

  Future<PcClipboardStatus> _fetch() async {
    final status = await ref.read(apiServiceProvider).getClipboard();
    if (status == null) throw Exception('Cannot reach server');
    return status;
  }

  Future<void> _refresh() async {
    try {
      state = AsyncData(await _fetch());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ── App launcher status (configurable poll) ──────────────────────────────────

final appLauncherProvider = AsyncNotifierProvider.autoDispose<
    AppLauncherNotifier, AppLauncherStatus>(AppLauncherNotifier.new);

class AppLauncherNotifier extends AutoDisposeAsyncNotifier<AppLauncherStatus> {
  Timer? _timer;

  @override
  Future<AppLauncherStatus> build() async {
    final intervalSecs = ref.watch(dashboardPollIntervalProvider);
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(Duration(seconds: intervalSecs), (_) => _refresh());
    return _fetch();
  }

  Future<AppLauncherStatus> _fetch() async {
    final status = await ref.read(apiServiceProvider).getApps();
    if (status == null) throw Exception('Cannot reach server');
    return status;
  }

  Future<void> _refresh() async {
    try {
      state = AsyncData(await _fetch());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() => _refresh();
}
