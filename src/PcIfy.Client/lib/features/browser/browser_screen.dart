import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/constants/media_types.dart';
import 'background_crop_screen.dart';
import '../split_view/split_view_screen.dart' show SplitViewEntry;
import '../../core/models/bookmarked_folder.dart';
import '../../core/models/file_entry.dart';
import '../../core/models/folder_listing.dart';
import '../../core/models/folder_prefs.dart';
import '../../core/utils/grid_density_helper.dart';
import '../../providers/services_providers.dart';
import '../../widgets/folder_background_image.dart';
import '../home/home_screen.dart';

// --- Data classes ---

class _BrowserItem {
  const _BrowserItem({required this.entry, this.thumbnailUri, this.streamUri});
  final FileEntry entry;
  final String? thumbnailUri;
  final String? streamUri;
}

class _BrowserState {
  const _BrowserState({
    required this.listing,
    required this.items,
    required this.prefs,
    required this.isBookmarked,
    required this.density,
    required this.canNavigateBack,
    this.backgroundImageUri,
    this.isSelecting = false,
    this.selectedPaths = const {},
  });
  final FolderListing? listing;
  final List<_BrowserItem> items;
  final FolderPrefs prefs;
  final bool isBookmarked;
  final GridDensity density;
  final bool canNavigateBack;
  final String? backgroundImageUri;
  final bool isSelecting;
  final Set<String> selectedPaths;

  _BrowserState copyWith({
    FolderListing? listing,
    List<_BrowserItem>? items,
    FolderPrefs? prefs,
    bool? isBookmarked,
    GridDensity? density,
    bool? canNavigateBack,
    String? backgroundImageUri,
    bool clearBackgroundUri = false,
    bool? isSelecting,
    Set<String>? selectedPaths,
  }) =>
      _BrowserState(
        listing: listing ?? this.listing,
        items: items ?? this.items,
        prefs: prefs ?? this.prefs,
        isBookmarked: isBookmarked ?? this.isBookmarked,
        density: density ?? this.density,
        canNavigateBack: canNavigateBack ?? this.canNavigateBack,
        backgroundImageUri: clearBackgroundUri
            ? null
            : (backgroundImageUri ?? this.backgroundImageUri),
        isSelecting: isSelecting ?? this.isSelecting,
        selectedPaths: selectedPaths ?? this.selectedPaths,
      );
}

// --- Providers ---

final _browserPathProvider = Provider.autoDispose<String>((ref) => '');

class _BrowserNotifier extends AutoDisposeAsyncNotifier<_BrowserState> {
  final _history = <String>[];
  bool navigating = false;

  @override
  Future<_BrowserState> build() async {
    final path = ref.watch(_browserPathProvider);
    _history
      ..clear()
      ..add(path);
    final loaded = await _load(path);
    // When opening a bookmarked nested folder, seed its parent so back navigation works.
    final parentPath = loaded.listing?.parentPath;
    if (parentPath != null && parentPath.isNotEmpty) {
      _history.insert(0, parentPath);
      return loaded.copyWith(canNavigateBack: true);
    }
    return loaded;
  }

  Future<void> navigateTo(String path) async {
    navigating = true;
    state = const AsyncLoading<_BrowserState>().copyWithPrevious(state);
    _history.add(path);
    state = await AsyncValue.guard(() => _load(path));
    navigating = false;
  }

  Future<void> navigateBack() async {
    if (_history.length <= 1) return;
    _history.removeLast();
    navigating = true;
    state = const AsyncLoading<_BrowserState>().copyWithPrevious(state);
    final result = await AsyncValue.guard(() => _load(_history.last));
    // If we've reached the start of history but the loaded folder still has a parent,
    // lazily extend history so the user can keep navigating back (handles deep bookmarks).
    if (_history.length == 1 && result.hasValue) {
      final parentPath = result.requireValue.listing?.parentPath;
      if (parentPath != null && parentPath.isNotEmpty) {
        _history.insert(0, parentPath);
        state = AsyncData(result.requireValue.copyWith(canNavigateBack: true));
        navigating = false;
        return;
      }
    }
    state = result;
    navigating = false;
  }

  Future<_BrowserState> _load(String path) async {
    final api = ref.read(apiServiceProvider);
    final prefs = ref.read(sharedPrefsProvider);
    final density =
        GridDensityHelper.fromString(prefs.getString('grid_density') ?? 'normal');

    FolderListing listing;

    if (path.isEmpty) {
      final roots = await api.getRoots();
      if (roots == null || roots.isEmpty) {
        throw Exception('No source directories configured on server.');
      }
      if (roots.length == 1) {
        final l = await api.getFolderListing(roots.first.path);
        if (l == null) throw Exception('Could not load folder.');
        listing = l;
      } else {
        final entries = roots
            .map((r) => FileEntry(
                  name: r.name,
                  path: r.path,
                  type: FileType.folder,
                  sizeBytes: 0,
                  lastModified: DateTime.fromMillisecondsSinceEpoch(0),
                  hasThumbnail: false,
                ))
            .toList();
        listing = FolderListing(
            path: '', parentPath: null, displayName: 'Drives', entries: entries);
      }
    } else {
      final l = await api.getFolderListing(path);
      if (l == null) throw Exception('Could not load folder.');
      listing = l;
    }

    final folderPrefsService = ref.read(folderPrefsServiceProvider);
    final folderPrefs = await folderPrefsService.getPrefs(listing.path);
    final isBookmarked = ref.read(bookmarkServiceProvider).isBookmarked(listing.path);
    final items = await _buildItems(listing.entries);

    String? bgUri;
    if (folderPrefs.backgroundImagePath != null) {
      bgUri = await api.buildStreamUriWithToken(folderPrefs.backgroundImagePath!);
    }

    return _BrowserState(
      listing: listing,
      items: items,
      prefs: folderPrefs,
      isBookmarked: isBookmarked,
      density: density,
      canNavigateBack: _history.length > 1,
      backgroundImageUri: bgUri,
    );
  }

  Future<List<_BrowserItem>> _buildItems(List<FileEntry> entries) async {
    final api = ref.read(apiServiceProvider);
    final result = <_BrowserItem>[];
    for (final e in entries) {
      final String? thumbUri =
          e.hasThumbnail ? await api.buildThumbnailUriWithToken(e.path) : null;
      // Always build stream URI for playable types so external player actions
      // work even when the server hasn't generated a thumbnail yet.
      final String? streamUri =
          (e.type == FileType.video || e.type == FileType.image)
              ? await api.buildStreamUriWithToken(e.path)
              : null;
      result.add(_BrowserItem(entry: e, thumbnailUri: thumbUri, streamUri: streamUri));
    }
    return result;
  }

  Future<void> toggleBookmark() async {
    final s = state.valueOrNull;
    if (s?.listing == null) return;
    final svc = ref.read(bookmarkServiceProvider);
    final path = s!.listing!.path;
    if (s.isBookmarked) {
      await svc.removeBookmark(path);
    } else {
      await svc.addBookmark(BookmarkedFolder(
          path: path, displayName: s.listing!.displayName));
    }
    ref.invalidate(bookmarksProvider);
    state = AsyncData(s.copyWith(isBookmarked: !s.isBookmarked));
  }

  void cycleDensity() {
    final s = state.valueOrNull;
    if (s == null) return;
    final next = GridDensityHelper.next(s.density);
    ref.read(sharedPrefsProvider).setString('grid_density', next.name);
    state = AsyncData(s.copyWith(density: next));
  }

  Future<void> setBackgroundImage(
    String serverPath, {
    double? cropOffsetDx,
    double? cropOffsetDy,
    double? cropScale,
  }) async {
    final s = state.valueOrNull;
    if (s?.listing == null) return;
    final updated = s!.prefs.copyWith(
      backgroundImagePath: serverPath,
      cropOffsetDx: cropOffsetDx,
      cropOffsetDy: cropOffsetDy,
      cropScale: cropScale,
      clearCrop: cropOffsetDx == null,
    );
    await ref
        .read(folderPrefsServiceProvider)
        .savePrefs(s.listing!.path, updated);
    final uri = await ref.read(apiServiceProvider).buildStreamUriWithToken(serverPath);
    state = AsyncData(s.copyWith(prefs: updated, backgroundImageUri: uri));
  }

  void enterSelection(String firstPath) {
    final s = state.valueOrNull;
    if (s == null) return;
    state = AsyncData(s.copyWith(isSelecting: true, selectedPaths: {firstPath}));
  }

  void toggleSelection(String path) {
    final s = state.valueOrNull;
    if (s == null) return;
    final updated = Set<String>.from(s.selectedPaths);
    if (updated.contains(path)) {
      updated.remove(path);
    } else {
      updated.add(path);
    }
    state = AsyncData(s.copyWith(selectedPaths: updated));
  }

  void clearSelection() {
    final s = state.valueOrNull;
    if (s == null) return;
    state = AsyncData(s.copyWith(isSelecting: false, selectedPaths: {}));
  }

  Future<void> clearBackgroundImage() async {
    final s = state.valueOrNull;
    if (s?.listing == null) return;
    final updated = s!.prefs.copyWith(clearBackground: true);
    await ref
        .read(folderPrefsServiceProvider)
        .savePrefs(s.listing!.path, updated);
    state = AsyncData(s.copyWith(prefs: updated, clearBackgroundUri: true));
  }
}

final _browserNotifierProvider =
    AutoDisposeAsyncNotifierProvider<_BrowserNotifier, _BrowserState>(
        _BrowserNotifier.new,
        dependencies: [_browserPathProvider]);

// --- Screen ---

class BrowserScreen extends ConsumerWidget {
  const BrowserScreen({super.key, this.path});
  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [_browserPathProvider.overrideWithValue(path ?? '')],
      child: const _BrowserBody(),
    );
  }
}

class _BrowserBody extends ConsumerWidget {
  const _BrowserBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_browserNotifierProvider);
    final isNavigating =
        async.isLoading && ref.read(_browserNotifierProvider.notifier).navigating;
    return Stack(
      children: [
        async.when(
          skipLoadingOnReload: true,
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, _) {
            final msg = err is Exception
                ? err.toString().replaceFirst('Exception: ', '')
                : err.toString();
            return Scaffold(
                appBar: AppBar(), body: Center(child: Text(msg)));
          },
          data: (s) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _BrowserLoaded(
              key: ValueKey(s.listing?.path ?? ''),
              state: s,
            ),
          ),
        ),
        if (isNavigating)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _BrowserLoaded extends ConsumerWidget {
  const _BrowserLoaded({super.key, required this.state});
  final _BrowserState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(_browserNotifierProvider.notifier);
    final listing = state.listing!;
    final hasBg = state.backgroundImageUri != null;

    final AppBar appBar;
    if (state.isSelecting) {
      final selectedItems = state.items
          .where((i) => state.selectedPaths.contains(i.entry.path))
          .toList();
      final single = selectedItems.length == 1;
      final singleVideo = single && selectedItems.first.entry.type == FileType.video;
      final singleImage = single && selectedItems.first.entry.type == FileType.image;
      final fgColor = hasBg ? Colors.white : Theme.of(context).colorScheme.primary;
      appBar = AppBar(
        backgroundColor: hasBg ? Colors.black87 : null,
        foregroundColor: hasBg ? Colors.white : null,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: notifier.clearSelection,
        ),
        title: Text('${state.selectedPaths.length} selected'),
        actions: [
          Tooltip(
            message: state.selectedPaths.length > 3
                ? 'Select up to 3 items for Split View'
                : '',
            child: TextButton.icon(
              onPressed: state.selectedPaths.isEmpty ||
                      state.selectedPaths.length > 3
                  ? null
                  : () => _openSplitView(context, ref, listing),
              icon: const Icon(Icons.view_column_outlined),
              label: const Text('Open in Split View'),
              style: TextButton.styleFrom(foregroundColor: fgColor),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: hasBg ? Colors.white : null),
            onSelected: (v) =>
                _onSelectionMenuAction(context, ref, listing, v, selectedItems),
            itemBuilder: (_) => [
              if (singleVideo)
                const PopupMenuItem(value: 'play', child: Text('Play')),
              if (singleImage)
                const PopupMenuItem(value: 'view', child: Text('View')),
              PopupMenuItem(
                value: 'external',
                enabled: singleVideo,
                child: const Text('Open in external player'),
              ),
              PopupMenuItem(
                value: 'download',
                child: Text(selectedItems.length > 1 ? 'Download all' : 'Download'),
              ),
            ],
          ),
        ],
      );
    } else {
      appBar = AppBar(
        backgroundColor: hasBg ? Colors.transparent : null,
        foregroundColor: hasBg ? Colors.white : null,
        elevation: hasBg ? 0 : null,
        title: Text(listing.displayName),
        leading: state.canNavigateBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: notifier.navigateBack,
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(
              state.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
              color: hasBg ? Colors.white : Theme.of(context).colorScheme.primary,
            ),
            onPressed: notifier.toggleBookmark,
          ),
          IconButton(
            icon: Icon(
              state.prefs.backgroundImagePath != null
                  ? Icons.wallpaper
                  : Icons.image_outlined,
              color: hasBg ? Colors.white : Theme.of(context).colorScheme.primary,
            ),
            tooltip: state.prefs.backgroundImagePath != null
                ? 'Background options'
                : 'Set background',
            onPressed: () => _onBackgroundTap(context, ref, notifier, listing,
                hasBackground: state.prefs.backgroundImagePath != null,
                existingImagePath: state.prefs.backgroundImagePath),
          ),
        ],
      );
    }

    final grid = LayoutBuilder(builder: (context, constraints) {
      final cols =
          GridDensityHelper.getColumnCount(constraints.maxWidth, state.density);
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        // ignore: deprecated_member_use
        cacheExtent: 600,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 0.85,
        ),
        itemCount: state.items.length,
        itemBuilder: (context, i) {
          final item = state.items[i];
          final isSelectable = item.entry.type == FileType.image ||
              item.entry.type == FileType.video;
          final isSelected = state.selectedPaths.contains(item.entry.path);
          return RepaintBoundary(
            child: _FileGridItem(
              item: item,
              hasBackground: hasBg,
              isSelecting: state.isSelecting && isSelectable,
              isSelected: isSelected,
              onTap: () => _onTap(context, ref, item),
              onLongPress: () => _onLongPress(context, ref, item, listing),
            ),
          );
        },
      );
    });

    if (hasBg) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        body: Stack(
          fit: StackFit.expand,
          children: [
            FolderBackgroundImage(
              imageUri: state.backgroundImageUri!,
              prefs: state.prefs,
            ),
            DecoratedBox(
              decoration:
                  BoxDecoration(color: Colors.black.withValues(alpha: 0.35)),
            ),
            Column(
              children: [
                SizedBox(
                    height: MediaQuery.viewPaddingOf(context).top +
                        kToolbarHeight),
                _DensityToolbar(
                    count: state.items.length,
                    density: state.density,
                    onCycle: notifier.cycleDensity,
                    hasBackground: true),
                Expanded(child: grid),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: Column(
        children: [
          _DensityToolbar(
              count: state.items.length,
              density: state.density,
              onCycle: notifier.cycleDensity),
          Expanded(child: grid),
        ],
      ),
    );
  }

  Future<void> _onBackgroundTap(
    BuildContext context,
    WidgetRef ref,
    _BrowserNotifier notifier,
    FolderListing listing, {
    required bool hasBackground,
    String? existingImagePath,
  }) async {
    if (hasBackground) {
      // Ask user to change or remove existing background
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Background Image',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.tune_outlined),
                title: const Text('Adjust image'),
                onTap: () => Navigator.pop(context, 'adjust'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Change background'),
                onTap: () => Navigator.pop(context, 'change'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove background'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ],
          ),
        ),
      );
      if (!context.mounted || action == null) return;
      if (action == 'remove') {
        await notifier.clearBackgroundImage();
        return;
      }
      if (action == 'adjust') {
        final existingPath = existingImagePath;
        if (existingPath == null || !context.mounted) return;
        final imageUri =
            await ref.read(apiServiceProvider).buildStreamUriWithToken(existingPath);
        if (!context.mounted) return;
        final result = await context.push<BackgroundCropResult>(
          '/background-crop?imagePath=${Uri.encodeComponent(existingPath)}',
          extra: imageUri,
        );
        if (result != null) {
          await notifier.setBackgroundImage(
            result.imagePath,
            cropOffsetDx: result.cropOffsetDx,
            cropOffsetDy: result.cropOffsetDy,
            cropScale: result.cropScale,
          );
        }
        return;
      }
      // 'change' falls through to the picker below
    }
    // Open image picker → crop screen, defaulting to the existing background's folder
    final pickerStart = existingImagePath != null
        ? _parentFolderPath(existingImagePath)
        : listing.path;
    final picked = await context.push<String>(
        '/image-picker?path=${Uri.encodeComponent(pickerStart)}');
    if (picked == null || !context.mounted) return;
    final imageUri =
        await ref.read(apiServiceProvider).buildStreamUriWithToken(picked);
    if (!context.mounted) return;
    final result = await context.push<BackgroundCropResult>(
      '/background-crop?imagePath=${Uri.encodeComponent(picked)}',
      extra: imageUri,
    );
    if (result != null) {
      await notifier.setBackgroundImage(
        result.imagePath,
        cropOffsetDx: result.cropOffsetDx,
        cropOffsetDy: result.cropOffsetDy,
        cropScale: result.cropScale,
      );
    }
  }

  String _parentFolderPath(String filePath) {
    final lastSlash = filePath.lastIndexOf('/');
    if (lastSlash > 0) return filePath.substring(0, lastSlash);
    final lastBackslash = filePath.lastIndexOf('\\');
    if (lastBackslash > 0) return filePath.substring(0, lastBackslash);
    return filePath;
  }

  Future<void> _onSelectionMenuAction(
    BuildContext context,
    WidgetRef ref,
    FolderListing listing,
    String action,
    List<_BrowserItem> selectedItems,
  ) async {
    if (selectedItems.isEmpty) return;
    final item = selectedItems.first;

    switch (action) {
      case 'play':
        ref.read(_browserNotifierProvider.notifier).clearSelection();
        context.push(
            '/player?path=${Uri.encodeComponent(item.entry.path)}&name=${Uri.encodeComponent(item.entry.name)}');
      case 'view':
        final media = listing.entries
            .where((x) => x.type == FileType.image || x.type == FileType.video)
            .toList();
        final idx = media.indexWhere((x) => x.path == item.entry.path);
        ref.read(_browserNotifierProvider.notifier).clearSelection();
        if (context.mounted) {
          context.push(
              '/gallery?path=${Uri.encodeComponent(listing.path)}&index=${idx < 0 ? 0 : idx}');
        }
      case 'external':
        final uri = item.streamUri ?? '';
        final mime = MediaTypes.getMimeType(MediaTypes.extensionOf(item.entry.name));
        ref.read(_browserNotifierProvider.notifier).clearSelection();
        await ref.read(externalPlayerServiceProvider).openVideo(uri, mime);
      case 'download':
        ref.read(_browserNotifierProvider.notifier).clearSelection();
        for (final sel in selectedItems) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Downloading ${sel.entry.name}…')));
          final saved = await ref
              .read(downloadServiceProvider)
              .downloadFile(sel.entry.path, sel.entry.name);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(saved != null
                    ? 'Saved: ${sel.entry.name}'
                    : 'Download failed: ${sel.entry.name}')));
          }
        }
    }
  }

  void _openSplitView(BuildContext context, WidgetRef ref, FolderListing listing) {
    final s = ref.read(_browserNotifierProvider).valueOrNull;
    if (s == null || s.selectedPaths.isEmpty) return;
    final entries = s.items
        .where((i) => s.selectedPaths.contains(i.entry.path))
        .map((i) => SplitViewEntry(
              name: i.entry.name,
              filePath: i.entry.path,
              isVideo: i.entry.type == FileType.video,
              streamUri: i.streamUri,
              thumbnailUri: i.thumbnailUri,
            ))
        .toList();
    ref.read(_browserNotifierProvider.notifier).clearSelection();
    context.push('/split-view', extra: {
      'folderPath': listing.path,
      'entries': entries,
    });
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref, _BrowserItem item) async {
    // In selection mode, tapping a media item toggles selection
    final s = ref.read(_browserNotifierProvider).valueOrNull;
    if (s != null && s.isSelecting) {
      final e = item.entry;
      if (e.type == FileType.image || e.type == FileType.video) {
        final notifier = ref.read(_browserNotifierProvider.notifier);
        notifier.toggleSelection(e.path);
      }
      return;
    }
    final e = item.entry;
    switch (e.type) {
      case FileType.folder:
        ref.read(_browserNotifierProvider.notifier).navigateTo(e.path);
      case FileType.video:
        final alwaysExternal =
            ref.read(sharedPrefsProvider).getBool('always_external_player') ?? false;
        if (alwaysExternal) {
          final uri = item.streamUri ?? '';
          final mime = MediaTypes.getMimeType(MediaTypes.extensionOf(e.name));
          await ref.read(externalPlayerServiceProvider).openVideo(uri, mime);
        } else {
          final listing = ref.read(_browserNotifierProvider).valueOrNull?.listing;
          final media = listing?.entries
                  .where((x) =>
                      x.type == FileType.image || x.type == FileType.video)
                  .toList() ??
              [];
          final idx = media.indexWhere((x) => x.path == e.path);
          if (context.mounted) {
            context.push(
                '/gallery?path=${Uri.encodeComponent(listing?.path ?? '')}&index=${idx < 0 ? 0 : idx}');
          }
        }
      case FileType.image:
        final listing = ref.read(_browserNotifierProvider).valueOrNull?.listing;
        final media = listing?.entries
                .where((x) =>
                    x.type == FileType.image || x.type == FileType.video)
                .toList() ??
            [];
        final idx = media.indexWhere((x) => x.path == e.path);
        context.push(
            '/gallery?path=${Uri.encodeComponent(listing?.path ?? '')}&index=${idx < 0 ? 0 : idx}');
      default:
        await _downloadAndOpen(context, ref, item.entry);
    }
  }

  Future<void> _downloadAndOpen(
      BuildContext context, WidgetRef ref, FileEntry e) async {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Opening ${e.name}…')));
    final saved =
        await ref.read(downloadServiceProvider).downloadFile(e.path, e.name);
    if (!context.mounted) return;
    if (saved == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Download failed')));
      return;
    }
    final result = await OpenFilex.open(saved);
    if (context.mounted && result.type != ResultType.done) {
      messenger.showSnackBar(
          SnackBar(content: Text('Cannot open file: ${result.message}')));
    }
  }

  Future<void> _onLongPress(BuildContext context, WidgetRef ref,
      _BrowserItem item, FolderListing listing) async {
    final e = item.entry;
    // Long-press on image/video → enter multi-select mode
    if (e.type == FileType.image || e.type == FileType.video) {
      final s = ref.read(_browserNotifierProvider).valueOrNull;
      if (s != null && !s.isSelecting) {
        ref.read(_browserNotifierProvider.notifier).enterSelection(e.path);
        return;
      }
    }
    final actions = <String, String>{};
    if (e.type == FileType.folder) {
      actions['open'] = 'Open';
      actions['bookmark'] = 'Bookmark folder';
    } else if (e.type == FileType.video) {
      actions['play'] = 'Play';
      actions['external'] = 'Open in external player';
      actions['download'] = 'Download';
    } else if (e.type == FileType.image) {
      actions['view'] = 'View';
      actions['download'] = 'Download';
    } else {
      actions['open_file'] = 'Open';
      actions['download'] = 'Download';
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(e.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            const Divider(height: 1),
            ...actions.entries.map((kv) => ListTile(
                  title: Text(kv.value),
                  onTap: () => Navigator.pop(context, kv.key),
                )),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case 'open':
        ref.read(_browserNotifierProvider.notifier).navigateTo(e.path);
      case 'bookmark':
        await ref.read(bookmarkServiceProvider).addBookmark(
            BookmarkedFolder(path: e.path, displayName: e.name));
        ref.invalidate(bookmarksProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Bookmarked ${e.name}')));
        }
      case 'play':
        context.push(
            '/player?path=${Uri.encodeComponent(e.path)}&name=${Uri.encodeComponent(e.name)}');
      case 'external':
        final uri = item.streamUri ?? '';
        final mime = MediaTypes.getMimeType(MediaTypes.extensionOf(e.name));
        await ref.read(externalPlayerServiceProvider).openVideo(uri, mime);
      case 'download':
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Downloading ${e.name}…')));
        }
        final saved = await ref
            .read(downloadServiceProvider)
            .downloadFile(e.path, e.name);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(saved != null ? 'Saved to $saved' : 'Download failed')));
        }
      case 'view':
        final media = listing.entries
            .where((x) => x.type == FileType.image || x.type == FileType.video)
            .toList();
        final idx = media.indexWhere((x) => x.path == e.path);
        context.push(
            '/gallery?path=${Uri.encodeComponent(listing.path)}&index=${idx < 0 ? 0 : idx}');
      case 'open_file':
        await _downloadAndOpen(context, ref, e);
    }
  }
}

// --- Sub-widgets ---


class _DensityToolbar extends StatelessWidget {
  const _DensityToolbar({
    required this.count,
    required this.density,
    required this.onCycle,
    this.hasBackground = false,
  });
  final int count;
  final GridDensity density;
  final VoidCallback onCycle;
  final bool hasBackground;

  @override
  Widget build(BuildContext context) {
    final style = hasBackground
        ? Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.white70)
        : Theme.of(context).textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text('$count items', style: style),
          const Spacer(),
          TextButton.icon(
            onPressed: onCycle,
            style: hasBackground
                ? TextButton.styleFrom(foregroundColor: Colors.white)
                : null,
            icon: const Icon(Icons.grid_view, size: 18),
            label: Text(GridDensityHelper.label(density)),
          ),
        ],
      ),
    );
  }
}

class _FileGridItem extends StatelessWidget {
  const _FileGridItem({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    this.hasBackground = false,
    this.isSelecting = false,
    this.isSelected = false,
  });
  final _BrowserItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool hasBackground;
  final bool isSelecting;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entry = item.entry;
    final icon = _iconFor(entry.type);

    final iconColor = cs.outline;
    final labelStyle = Theme.of(context).textTheme.labelSmall;

    final cardContent = Column(
      children: [
        Expanded(
          child: item.thumbnailUri != null
              ? CachedNetworkImage(
                  imageUrl: item.thumbnailUri!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  memCacheWidth: 320,
                  placeholder: (_, __) =>
                      Center(child: Icon(icon, size: 40, color: iconColor)),
                  errorWidget: (_, __, ___) =>
                      Center(child: Icon(icon, size: 40, color: iconColor)),
                )
              : Center(
                  child: Icon(icon,
                      size: 48,
                      color: cs.primary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            entry.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
        ),
      ],
    );

    final selectionOverlay = isSelecting
        ? Positioned.fill(
            child: Stack(children: [
              if (isSelected)
                const ColoredBox(color: Color(0x4400AAFF)),
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? Colors.lightBlue : Colors.white70,
                  size: 22,
                ),
              ),
            ]),
          )
        : null;

    if (hasBackground) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected
                    ? Colors.lightBlue
                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                width: isSelected ? 2.0 : 1.0),
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: Stack(children: [
              cardContent,
              if (selectionOverlay != null) selectionOverlay,
            ]),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.hardEdge,
      shape: isSelected
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.lightBlue, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(children: [
          cardContent,
          if (selectionOverlay != null) selectionOverlay,
        ]),
      ),
    );
  }

  IconData _iconFor(FileType type) => switch (type) {
        FileType.folder => Icons.folder,
        FileType.video => Icons.videocam,
        FileType.image => Icons.image,
        FileType.audio => Icons.audio_file,
        FileType.document => Icons.description,
        FileType.archive => Icons.folder_zip,
        FileType.unknown => Icons.insert_drive_file,
      };
}
