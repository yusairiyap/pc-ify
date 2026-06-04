import 'dart:async' show unawaited;
import 'dart:io' show Directory, File;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart' hide FileType;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/media_types.dart';
import '../../core/models/bookmarked_folder.dart';
import '../../core/models/file_entry.dart';
import '../../core/models/folder_listing.dart';
import '../../core/models/folder_prefs.dart';
import '../../core/models/transfer_task.dart';
import '../../core/utils/file_size_formatter.dart';
import '../../core/utils/grid_density_helper.dart';
import '../../core/utils/sort_helper.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/services_providers.dart';
import '../../providers/transfer_providers.dart';
import '../../widgets/folder_background_image.dart';
import '../../widgets/video_background_player.dart';
import 'background_crop_screen.dart';
import 'background_video_trim_screen.dart';
import '../split_view/split_view_screen.dart' show SplitViewEntry;

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
    required this.sort,
    required this.canNavigateBack,
    this.backgroundImageUri,
    this.backgroundVideoUri,
    this.isSelecting = false,
    this.selectedPaths = const {},
  });
  final FolderListing? listing;
  final List<_BrowserItem> items;
  final FolderPrefs prefs;
  final bool isBookmarked;
  final GridDensity density;
  final SortOption sort;
  final bool canNavigateBack;
  final String? backgroundImageUri;
  final String? backgroundVideoUri;
  final bool isSelecting;
  final Set<String> selectedPaths;

  bool get hasBg => backgroundImageUri != null || backgroundVideoUri != null;

  _BrowserState copyWith({
    FolderListing? listing,
    List<_BrowserItem>? items,
    FolderPrefs? prefs,
    bool? isBookmarked,
    GridDensity? density,
    SortOption? sort,
    bool? canNavigateBack,
    String? backgroundImageUri,
    String? backgroundVideoUri,
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
        sort: sort ?? this.sort,
        canNavigateBack: canNavigateBack ?? this.canNavigateBack,
        backgroundImageUri: clearBackgroundUri
            ? null
            : (backgroundImageUri ?? this.backgroundImageUri),
        backgroundVideoUri: clearBackgroundUri
            ? null
            : (backgroundVideoUri ?? this.backgroundVideoUri),
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

  Future<void> reload() async {
    if (state.isLoading) return;
    final path = state.valueOrNull?.listing?.path ??
        (_history.isNotEmpty ? _history.last : '');
    navigating = true;
    state = const AsyncLoading<_BrowserState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(path));
    navigating = false;
  }

  Future<_BrowserState> _load(String path) async {
    final api = ref.read(apiServiceProvider);
    final prefs = ref.read(sharedPrefsProvider);
    final density =
        GridDensityHelper.fromString(prefs.getString('grid_density') ?? 'normal');
    final sort = sortFromString(prefs.getString(sortPrefKey));

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
            path: '',
            parentPath: null,
            displayName: 'Drives',
            entries: entries);
      }
    } else {
      final l = await api.getFolderListing(path);
      if (l == null) throw Exception('Could not load folder.');
      listing = l;
    }

    final folderPrefsService = ref.read(folderPrefsServiceProvider);
    final folderPrefs = await folderPrefsService.getPrefs(listing.path);
    final isBookmarked =
        ref.read(bookmarkServiceProvider).isBookmarked(listing.path);
    final sortedEntries = applySortToEntries(listing.entries, sort);
    final items = await _buildItems(sortedEntries);

    String? bgImageUri;
    if (folderPrefs.backgroundImagePath != null) {
      bgImageUri =
          await api.buildStreamUriWithToken(folderPrefs.backgroundImagePath!);
    }
    String? bgVideoUri;
    if (folderPrefs.backgroundVideoPath != null) {
      bgVideoUri =
          await api.buildStreamUriWithToken(folderPrefs.backgroundVideoPath!);
    }

    return _BrowserState(
      listing: listing,
      items: items,
      prefs: folderPrefs,
      isBookmarked: isBookmarked,
      density: density,
      sort: sort,
      canNavigateBack: _history.length > 1,
      backgroundImageUri: bgImageUri,
      backgroundVideoUri: bgVideoUri,
    );
  }

  Future<List<_BrowserItem>> _buildItems(List<FileEntry> entries) async {
    final api = ref.read(apiServiceProvider);
    final result = <_BrowserItem>[];
    for (final e in entries) {
      final String? thumbUri =
          e.hasThumbnail ? await api.buildThumbnailUriWithToken(e.path) : null;
      final String? streamUri =
          (e.type == FileType.video || e.type == FileType.image)
              ? await api.buildStreamUriWithToken(e.path)
              : null;
      result.add(
          _BrowserItem(entry: e, thumbnailUri: thumbUri, streamUri: streamUri));
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
      await svc.addBookmark(
          BookmarkedFolder(path: path, displayName: s.listing!.displayName));
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

  void setSortOption(SortOption sort) {
    final s = state.valueOrNull;
    if (s == null) return;
    ref.read(sharedPrefsProvider).setString(sortPrefKey, sort.name);
    if (s.listing == null) {
      state = AsyncData(s.copyWith(sort: sort));
      return;
    }
    final sorted = applySortToEntries(
      s.items.map((i) => i.entry).toList(),
      sort,
    );
    final uriMap = {for (final i in s.items) i.entry.path: i};
    final newItems = sorted
        .map((e) => uriMap[e.path] ?? _BrowserItem(entry: e))
        .toList();
    state = AsyncData(s.copyWith(items: newItems, sort: sort));
  }

  Future<void> setBackgroundImage(
    String serverPath, {
    double? cropOffsetDx,
    double? cropOffsetDy,
    double? cropScale,
  }) async {
    final s = state.valueOrNull;
    if (s?.listing == null) return;
    final snap = s!;
    final updated = FolderPrefs(
      backgroundImagePath: serverPath,
      cropOffsetDx: cropOffsetDx,
      cropOffsetDy: cropOffsetDy,
      cropScale: cropScale,
    );
    await ref
        .read(folderPrefsServiceProvider)
        .savePrefs(snap.listing!.path, updated);
    final uri =
        await ref.read(apiServiceProvider).buildStreamUriWithToken(serverPath);
    state = AsyncData(_BrowserState(
      listing: snap.listing,
      items: snap.items,
      prefs: updated,
      isBookmarked: snap.isBookmarked,
      density: snap.density,
      sort: snap.sort,
      canNavigateBack: snap.canNavigateBack,
      backgroundImageUri: uri,
      backgroundVideoUri: null,
      isSelecting: snap.isSelecting,
      selectedPaths: snap.selectedPaths,
    ));
  }

  Future<void> setBackgroundVideo(
    String serverPath, {
    int? loopStartMs,
    int? loopEndMs,
  }) async {
    final s = state.valueOrNull;
    if (s?.listing == null) return;
    final snap = s!;
    final updated = FolderPrefs(
      backgroundVideoPath: serverPath,
      videoLoopStartMs: loopStartMs,
      videoLoopEndMs: loopEndMs,
    );
    await ref
        .read(folderPrefsServiceProvider)
        .savePrefs(snap.listing!.path, updated);
    final uri =
        await ref.read(apiServiceProvider).buildStreamUriWithToken(serverPath);
    state = AsyncData(_BrowserState(
      listing: snap.listing,
      items: snap.items,
      prefs: updated,
      isBookmarked: snap.isBookmarked,
      density: snap.density,
      sort: snap.sort,
      canNavigateBack: snap.canNavigateBack,
      backgroundImageUri: null,
      backgroundVideoUri: uri,
      isSelecting: snap.isSelecting,
      selectedPaths: snap.selectedPaths,
    ));
  }

  void enterSelection(String firstPath) {
    final s = state.valueOrNull;
    if (s == null) return;
    state =
        AsyncData(s.copyWith(isSelecting: true, selectedPaths: {firstPath}));
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

  Future<void> clearBackground() async {
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
    final isNavigating = async.isLoading &&
        ref.read(_browserNotifierProvider.notifier).navigating;
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
            return Scaffold(appBar: AppBar(), body: Center(child: Text(msg)));
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

class _BrowserLoaded extends ConsumerStatefulWidget {
  const _BrowserLoaded({super.key, required this.state});
  final _BrowserState state;

  @override
  ConsumerState<_BrowserLoaded> createState() => _BrowserLoadedState();
}

class _BrowserLoadedState extends ConsumerState<_BrowserLoaded> {
  // Set by item long-press so the background GestureDetector skips once.
  bool _itemLongPressConsumed = false;

  _BrowserState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(_browserNotifierProvider.notifier);
    final listing = state.listing!;
    final hasBg = state.hasBg;
    final canUpload = listing.path.isNotEmpty;

    final clipboard = ref.watch(clipboardProvider);
    final AppBar appBar;
    if (state.isSelecting) {
      final selectedItems = state.items
          .where((i) => state.selectedPaths.contains(i.entry.path))
          .toList();
      final single = selectedItems.length == 1;
      final singleVideo =
          single && selectedItems.first.entry.type == FileType.video;
      final singleImage =
          single && selectedItems.first.entry.type == FileType.image;
      final fgColor =
          hasBg ? Colors.white : Theme.of(context).colorScheme.primary;
      final errorColor = Theme.of(context).colorScheme.error;
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
              onPressed:
                  state.selectedPaths.isEmpty || state.selectedPaths.length > 3
                      ? null
                      : () => _openSplitView(context, listing),
              icon: const Icon(Icons.view_column_outlined),
              label: const Text('Open in Split View'),
              style: TextButton.styleFrom(foregroundColor: fgColor),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: hasBg ? Colors.white : null),
            onSelected: (v) =>
                _onSelectionMenuAction(context, listing, v, selectedItems),
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
                child: Text(selectedItems.length > 1
                    ? 'Download ${selectedItems.length} files'
                    : 'Download'),
              ),
              const PopupMenuItem(
                  value: 'copy', child: Text('Copy')),
              const PopupMenuItem(
                  value: 'cut', child: Text('Cut')),
              PopupMenuItem(
                value: 'delete',
                child:
                    Text('Delete', style: TextStyle(color: errorColor)),
              ),
              if (single && (singleVideo || singleImage))
                const PopupMenuItem(
                    value: 'set_bg',
                    child: Text('Set as folder background')),
              if (single)
                const PopupMenuItem(
                    value: 'properties', child: Text('Properties')),
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
          if (canUpload)
            IconButton(
              icon: Icon(
                Icons.upload_outlined,
                color: hasBg
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
              ),
              tooltip: 'Upload files',
              onPressed: () => _showUploadOptions(context),
            ),
          if (clipboard != null && canUpload)
            IconButton(
              icon: Icon(
                Icons.content_paste_rounded,
                color: hasBg
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
              ),
              tooltip:
                  'Paste ${clipboard.paths.length} item${clipboard.paths.length > 1 ? 's' : ''} (${clipboard.mode == ClipboardMode.cut ? 'move' : 'copy'})',
              onPressed: () => _paste(context),
            ),
          IconButton(
            icon: Icon(
              state.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
              color:
                  hasBg ? Colors.white : Theme.of(context).colorScheme.primary,
            ),
            onPressed: notifier.toggleBookmark,
          ),
          IconButton(
            icon: Icon(
              state.prefs.hasBackground
                  ? Icons.wallpaper
                  : Icons.image_outlined,
              color:
                  hasBg ? Colors.white : Theme.of(context).colorScheme.primary,
            ),
            tooltip: state.prefs.hasBackground
                ? 'Background options'
                : 'Set background',
            onPressed: () => _onBackgroundTap(context, notifier, listing,
                prefs: state.prefs),
          ),
        ],
      );
    }

    final grid = AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: LayoutBuilder(
        key: ValueKey('${state.density.name}_${state.sort.name}'),
        builder: (context, constraints) {
          final cols = GridDensityHelper.getColumnCount(
              constraints.maxWidth, state.density);
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: canUpload
                ? () {
                    if (_itemLongPressConsumed) {
                      _itemLongPressConsumed = false;
                      return;
                    }
                    _showUploadOptions(context);
                  }
                : null,
            child: GridView.builder(
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
                final isSelected =
                    state.selectedPaths.contains(item.entry.path);
                return RepaintBoundary(
                  child: _FileGridItem(
                    item: item,
                    hasBackground: hasBg,
                    isSelecting: state.isSelecting && isSelectable,
                    isSelected: isSelected,
                    onTap: () => _onTap(context, item),
                    onLongPress: () {
                      _itemLongPressConsumed = true;
                      _onLongPress(context, item, listing);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );

    if (hasBg) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (state.backgroundVideoUri != null)
              VideoBackgroundPlayer(
                videoUri: state.backgroundVideoUri!,
                prefs: state.prefs,
              )
            else
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
                    height:
                        MediaQuery.viewPaddingOf(context).top + kToolbarHeight),
                _DensityToolbar(
                    count: state.items.length,
                    density: state.density,
                    sort: state.sort,
                    onCycle: notifier.cycleDensity,
                    onSort: notifier.setSortOption,
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
              sort: state.sort,
              onCycle: notifier.cycleDensity,
              onSort: notifier.setSortOption),
          Expanded(child: grid),
        ],
      ),
    );
  }

  // ── Upload ─────────────────────────────────────────────────────────────────

  Future<void> _showUploadOptions(BuildContext context) async {
    final serverFolder = state.listing?.path;
    if (serverFolder == null || serverFolder.isEmpty) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Upload to: ${state.listing!.displayName}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Upload files'),
              subtitle: const Text('Pick one or more files'),
              onTap: () => Navigator.pop(context, 'files'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_folder_upload_outlined),
              title: const Text('Upload folder contents'),
              subtitle: const Text('Pick a folder and upload its files'),
              onTap: () => Navigator.pop(context, 'folder'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    if (action == 'files') {
      await _pickAndUploadFiles(context, serverFolder);
    } else {
      await _pickAndUploadFolder(context, serverFolder);
    }
  }

  Future<void> _pickAndUploadFiles(
      BuildContext context, String serverFolder) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    if (!context.mounted) return;
    final files = result.files
        .where((f) => f.path != null)
        .map((f) => (localPath: f.path!, name: f.name))
        .toList();
    _startUploads(files, serverFolder);
  }

  Future<void> _pickAndUploadFolder(
      BuildContext context, String serverFolder) async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;

    final files = <({String localPath, String name})>[];
    try {
      final dir = Directory(dirPath);
      await for (final entity in dir.list()) {
        if (entity is File) {
          files.add((localPath: entity.path, name: p.basename(entity.path)));
        }
      }
    } catch (_) {}

    if (files.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No files found in selected folder')));
      return;
    }
    _startUploads(files, serverFolder);
  }

  void _startUploads(
    List<({String localPath, String name})> files,
    String serverFolder,
  ) {
    if (files.isEmpty) return;
    final manager = ref.read(transferManagerProvider.notifier);
    final notifier = ref.read(_browserNotifierProvider.notifier);
    final futures = <Future<void>>[];

    for (final f in files) {
      final (id, ct) = manager.addTransfer(f.name, TransferType.upload);
      futures.add(
        ref
            .read(uploadServiceProvider)
            .uploadFile(
              f.localPath,
              serverFolder,
              f.name,
              onProgress: (sent, total) =>
                  manager.updateProgress(id, sent, total),
              cancelToken: ct,
            )
            .then((success) {
          if (ct.isCancelled) return;
          if (success) {
            manager.complete(id);
          } else {
            manager.fail(id, 'Upload failed');
          }
        }),
      );
    }

    unawaited(Future.wait(futures).then((_) => notifier.reload()));
  }

  // ── Download helpers ───────────────────────────────────────────────────────

  void _startDownload(String serverPath, String fileName) {
    final manager = ref.read(transferManagerProvider.notifier);
    final (id, ct) = manager.addTransfer(fileName, TransferType.download);
    unawaited(
      ref
          .read(downloadServiceProvider)
          .downloadFile(
            serverPath,
            fileName,
            onProgress: (recv, total) =>
                manager.updateProgress(id, recv, total),
            cancelToken: ct,
          )
          .then((saved) {
        if (ct.isCancelled) return;
        if (saved != null) {
          manager.complete(id);
        } else {
          manager.fail(id, 'Download failed');
        }
      }),
    );
  }

  Future<void> _downloadAndOpen(BuildContext context, FileEntry e) async {
    if (!context.mounted) return;
    final manager = ref.read(transferManagerProvider.notifier);
    final (id, ct) = manager.addTransfer(e.name, TransferType.download);
    final saved = await ref.read(downloadServiceProvider).downloadFile(
          e.path,
          e.name,
          onProgress: (recv, total) => manager.updateProgress(id, recv, total),
          cancelToken: ct,
        );
    if (saved != null) {
      manager.complete(id);
      if (!context.mounted) return;
      final result = await OpenFilex.open(saved);
      if (context.mounted && result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open file: ${result.message}')));
      }
    } else {
      if (!ct.isCancelled) manager.fail(id, 'Download failed');
    }
  }

  // ── Background options ─────────────────────────────────────────────────────

  Future<void> _onBackgroundTap(
    BuildContext context,
    _BrowserNotifier notifier,
    FolderListing listing, {
    required FolderPrefs prefs,
  }) async {
    if (prefs.hasBackground) {
      final isVideo = prefs.isVideoBackground;
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  isVideo ? 'Background Video' : 'Background Image',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 1),
              if (isVideo)
                ListTile(
                  leading: const Icon(Icons.content_cut_outlined),
                  title: const Text('Trim video'),
                  onTap: () => Navigator.pop(context, 'trim'),
                )
              else
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
        await notifier.clearBackground();
        return;
      }
      if (action == 'adjust') {
        final existingPath = prefs.backgroundImagePath;
        if (existingPath == null || !context.mounted) return;
        final imageUri = await ref
            .read(apiServiceProvider)
            .buildStreamUriWithToken(existingPath);
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
      if (action == 'trim') {
        final existingPath = prefs.backgroundVideoPath;
        if (existingPath == null || !context.mounted) return;
        final videoUri = await ref
            .read(apiServiceProvider)
            .buildStreamUriWithToken(existingPath);
        if (!context.mounted) return;
        final result = await context.push<BackgroundVideoTrimResult>(
          '/background-video-trim',
          extra: {
            'videoUri': videoUri,
            'videoPath': existingPath,
            'startMs': prefs.videoLoopStartMs,
            'endMs': prefs.videoLoopEndMs,
          },
        );
        if (result != null) {
          await notifier.setBackgroundVideo(
            result.videoPath,
            loopStartMs: result.loopStartMs,
            loopEndMs: result.loopEndMs,
          );
        }
        return;
      }
    }
    final existingPath = prefs.backgroundImagePath ?? prefs.backgroundVideoPath;
    final pickerStart =
        existingPath != null ? _parentFolderPath(existingPath) : listing.path;
    final picked = await context
        .push<String>('/image-picker?path=${Uri.encodeComponent(pickerStart)}');
    if (picked == null || !context.mounted) return;

    if (_isVideoPath(picked)) {
      final videoUri =
          await ref.read(apiServiceProvider).buildStreamUriWithToken(picked);
      if (!context.mounted) return;
      final result = await context.push<BackgroundVideoTrimResult>(
        '/background-video-trim',
        extra: {'videoUri': videoUri, 'videoPath': picked},
      );
      if (result != null) {
        await notifier.setBackgroundVideo(
          result.videoPath,
          loopStartMs: result.loopStartMs,
          loopEndMs: result.loopEndMs,
        );
      }
    } else {
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
  }

  bool _isVideoPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return {
      'mp4', 'mkv', 'mov', 'avi', 'wmv', 'webm',
      'm4v', 'ts', 'flv', 'mpeg', 'mpg'
    }.contains(ext);
  }

  String _parentFolderPath(String filePath) {
    final lastSlash = filePath.lastIndexOf('/');
    if (lastSlash > 0) return filePath.substring(0, lastSlash);
    final lastBackslash = filePath.lastIndexOf('\\');
    if (lastBackslash > 0) return filePath.substring(0, lastBackslash);
    return filePath;
  }

  // ── Selection menu ─────────────────────────────────────────────────────────

  Future<void> _onSelectionMenuAction(
    BuildContext context,
    FolderListing listing,
    String action,
    List<_BrowserItem> selectedItems,
  ) async {
    if (selectedItems.isEmpty) return;
    final item = selectedItems.first;
    final notifier = ref.read(_browserNotifierProvider.notifier);

    switch (action) {
      case 'play':
        notifier.clearSelection();
        context.push(
            '/player?path=${Uri.encodeComponent(item.entry.path)}&name=${Uri.encodeComponent(item.entry.name)}');
      case 'view':
        final media = listing.entries
            .where((x) => x.type == FileType.image || x.type == FileType.video)
            .toList();
        final idx = media.indexWhere((x) => x.path == item.entry.path);
        notifier.clearSelection();
        if (context.mounted) {
          context.push(
              '/gallery?path=${Uri.encodeComponent(listing.path)}&index=${idx < 0 ? 0 : idx}');
        }
      case 'external':
        final uri = item.streamUri ?? '';
        final mime =
            MediaTypes.getMimeType(MediaTypes.extensionOf(item.entry.name));
        notifier.clearSelection();
        await ref.read(externalPlayerServiceProvider).openVideo(uri, mime);
      case 'download':
        notifier.clearSelection();
        for (final sel in selectedItems) {
          _startDownload(sel.entry.path, sel.entry.name);
        }
      case 'copy':
        notifier.clearSelection();
        ref.read(clipboardProvider.notifier).state = ClipboardState(
          paths: selectedItems.map((i) => i.entry.path).toList(),
          sourceFolderPath: listing.path,
          mode: ClipboardMode.copy,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${selectedItems.length} item${selectedItems.length > 1 ? 's' : ''} copied'),
            action: SnackBarAction(
              label: 'Cancel',
              onPressed: () =>
                  ref.read(clipboardProvider.notifier).state = null,
            ),
          ));
        }
      case 'cut':
        notifier.clearSelection();
        ref.read(clipboardProvider.notifier).state = ClipboardState(
          paths: selectedItems.map((i) => i.entry.path).toList(),
          sourceFolderPath: listing.path,
          mode: ClipboardMode.cut,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${selectedItems.length} item${selectedItems.length > 1 ? 's' : ''} cut'),
            action: SnackBarAction(
              label: 'Cancel',
              onPressed: () =>
                  ref.read(clipboardProvider.notifier).state = null,
            ),
          ));
        }
      case 'delete':
        notifier.clearSelection();
        if (context.mounted) {
          await _confirmAndDelete(
              context, selectedItems.map((i) => i.entry).toList());
        }
      case 'set_bg':
        notifier.clearSelection();
        if (context.mounted) {
          await _setItemAsBackground(context, item, listing);
        }
      case 'properties':
        notifier.clearSelection();
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => _PropertiesDialog(entry: item.entry, ref: ref),
          );
        }
    }
  }

  void _openSplitView(BuildContext context, FolderListing listing) {
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

  Future<void> _onTap(BuildContext context, _BrowserItem item) async {
    final s = ref.read(_browserNotifierProvider).valueOrNull;
    if (s != null && s.isSelecting) {
      final e = item.entry;
      if (e.type == FileType.image || e.type == FileType.video) {
        ref.read(_browserNotifierProvider.notifier).toggleSelection(e.path);
      }
      return;
    }
    final e = item.entry;
    switch (e.type) {
      case FileType.folder:
        ref.read(_browserNotifierProvider.notifier).navigateTo(e.path);
      case FileType.video:
        final alwaysExternal =
            ref.read(sharedPrefsProvider).getBool('always_external_player') ??
                false;
        if (alwaysExternal) {
          final uri = item.streamUri ?? '';
          final mime = MediaTypes.getMimeType(MediaTypes.extensionOf(e.name));
          await ref.read(externalPlayerServiceProvider).openVideo(uri, mime);
        } else {
          final listing =
              ref.read(_browserNotifierProvider).valueOrNull?.listing;
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
                .where(
                    (x) => x.type == FileType.image || x.type == FileType.video)
                .toList() ??
            [];
        final idx = media.indexWhere((x) => x.path == e.path);
        context.push(
            '/gallery?path=${Uri.encodeComponent(listing?.path ?? '')}&index=${idx < 0 ? 0 : idx}');
      default:
        await _downloadAndOpen(context, e);
    }
  }

  Future<void> _onLongPress(
      BuildContext context, _BrowserItem item, FolderListing listing) async {
    final e = item.entry;
    final actions = <String, String>{};

    if (e.type == FileType.folder) {
      actions['open'] = 'Open';
      actions['download'] = 'Download folder';
      actions['bookmark'] = 'Bookmark folder';
      actions['copy_item'] = 'Copy';
      actions['cut_item'] = 'Cut';
      actions['delete_item'] = 'Delete';
      actions['properties'] = 'Properties';
    } else if (e.type == FileType.video) {
      final s = ref.read(_browserNotifierProvider).valueOrNull;
      if (s != null && !s.isSelecting) {
        actions['select'] = 'Select';
        actions['set_bg'] = 'Set as folder background';
      }
      actions['play'] = 'Play';
      actions['external'] = 'Open in external player';
      actions['download'] = 'Download';
      actions['copy_item'] = 'Copy';
      actions['cut_item'] = 'Cut';
      actions['delete_item'] = 'Delete';
      actions['properties'] = 'Properties';
    } else if (e.type == FileType.image) {
      final s = ref.read(_browserNotifierProvider).valueOrNull;
      if (s != null && !s.isSelecting) {
        actions['select'] = 'Select';
        actions['set_bg'] = 'Set as folder background';
      }
      actions['view'] = 'View';
      actions['download'] = 'Download';
      actions['copy_item'] = 'Copy';
      actions['cut_item'] = 'Cut';
      actions['delete_item'] = 'Delete';
      actions['properties'] = 'Properties';
    } else {
      actions['open_file'] = 'Open';
      actions['download'] = 'Download';
      actions['copy_item'] = 'Copy';
      actions['cut_item'] = 'Cut';
      actions['delete_item'] = 'Delete';
      actions['properties'] = 'Properties';
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
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
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: actions.entries
                      .map((kv) => ListTile(
                            leading: Icon(_actionIcon(kv.key)),
                            title: Text(kv.value),
                            onTap: () => Navigator.pop(context, kv.key),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case 'select':
        ref.read(_browserNotifierProvider.notifier).enterSelection(e.path);
      case 'set_bg':
        await _setItemAsBackground(context, item, listing);
      case 'open':
        ref.read(_browserNotifierProvider.notifier).navigateTo(e.path);
      case 'bookmark':
        await ref
            .read(bookmarkServiceProvider)
            .addBookmark(BookmarkedFolder(path: e.path, displayName: e.name));
        ref.invalidate(bookmarksProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Bookmarked ${e.name}')));
        }
      case 'play':
        context.push(
            '/player?path=${Uri.encodeComponent(e.path)}&name=${Uri.encodeComponent(e.name)}');
      case 'external':
        final uri = item.streamUri ?? '';
        final mime = MediaTypes.getMimeType(MediaTypes.extensionOf(e.name));
        await ref.read(externalPlayerServiceProvider).openVideo(uri, mime);
      case 'download':
        if (e.type == FileType.folder) {
          await _startFolderDownload(context, e);
        } else {
          _startDownload(e.path, e.name);
        }
      case 'copy_item':
        ref.read(clipboardProvider.notifier).state = ClipboardState(
          paths: [e.path],
          sourceFolderPath: listing.path,
          mode: ClipboardMode.copy,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Copied ${e.name}'),
            action: SnackBarAction(
              label: 'Cancel',
              onPressed: () =>
                  ref.read(clipboardProvider.notifier).state = null,
            ),
          ));
        }
      case 'cut_item':
        ref.read(clipboardProvider.notifier).state = ClipboardState(
          paths: [e.path],
          sourceFolderPath: listing.path,
          mode: ClipboardMode.cut,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Cut ${e.name}'),
            action: SnackBarAction(
              label: 'Cancel',
              onPressed: () =>
                  ref.read(clipboardProvider.notifier).state = null,
            ),
          ));
        }
      case 'delete_item':
        if (context.mounted) {
          await _confirmAndDelete(context, [e]);
        }
      case 'view':
        final media = listing.entries
            .where((x) => x.type == FileType.image || x.type == FileType.video)
            .toList();
        final idx = media.indexWhere((x) => x.path == e.path);
        context.push(
            '/gallery?path=${Uri.encodeComponent(listing.path)}&index=${idx < 0 ? 0 : idx}');
      case 'open_file':
        await _downloadAndOpen(context, e);
      case 'properties':
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => _PropertiesDialog(entry: e, ref: ref),
          );
        }
    }
  }

  IconData _actionIcon(String key) => switch (key) {
        'select' => Icons.check_circle_outline,
        'set_bg' => Icons.wallpaper,
        'open' => Icons.folder_open,
        'bookmark' => Icons.bookmark_add_outlined,
        'play' => Icons.play_arrow_rounded,
        'external' => Icons.open_in_new,
        'download' => Icons.download_outlined,
        'view' => Icons.image_outlined,
        'open_file' => Icons.open_in_new,
        'copy_item' => Icons.copy_outlined,
        'cut_item' => Icons.content_cut_rounded,
        'delete_item' => Icons.delete_outline,
        'properties' => Icons.info_outline,
        _ => Icons.more_horiz,
      };

  // ── Paste ──────────────────────────────────────────────────────────────────

  Future<void> _paste(BuildContext context) async {
    final clipboard = ref.read(clipboardProvider);
    if (clipboard == null) return;
    final destFolder = state.listing?.path;
    if (destFolder == null || destFolder.isEmpty) return;

    if (destFolder == clipboard.sourceFolderPath) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Items are already in this folder')),
      );
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final isMove = clipboard.mode == ClipboardMode.cut;
    ref.read(clipboardProvider.notifier).state = null;

    final manager = ref.read(transferManagerProvider.notifier);
    final notifier = ref.read(_browserNotifierProvider.notifier);
    final api = ref.read(apiServiceProvider);
    final futures = <Future<void>>[];

    for (final srcPath in clipboard.paths) {
      final name = p.basename(srcPath);
      final type = isMove ? TransferType.move : TransferType.copy;
      final (id, _) = manager.addTransfer(name, type);
      futures.add(
        (isMove
                ? api.moveFile(srcPath, destFolder)
                : api.copyFile(srcPath, destFolder))
            .then((success) {
          if (success) {
            manager.complete(id);
          } else {
            manager.fail(id, '${isMove ? 'Move' : 'Copy'} failed');
          }
        }),
      );
    }

    unawaited(Future.wait(futures).then((_) => notifier.reload()));
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _confirmAndDelete(
      BuildContext context, List<FileEntry> entries) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text(entries.length == 1
            ? 'Delete "${entries.first.name}"? This cannot be undone.'
            : 'Delete ${entries.length} items? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    _startDeletes(entries);
  }

  void _startDeletes(List<FileEntry> entries) {
    final manager = ref.read(transferManagerProvider.notifier);
    final notifier = ref.read(_browserNotifierProvider.notifier);
    final api = ref.read(apiServiceProvider);
    final futures = <Future<void>>[];

    for (final entry in entries) {
      final (id, _) = manager.addTransfer(entry.name, TransferType.delete);
      futures.add(
        api.deleteFile(entry.path).then((success) {
          if (success) {
            manager.complete(id);
          } else {
            manager.fail(id, 'Delete failed');
          }
        }),
      );
    }

    unawaited(Future.wait(futures).then((_) => notifier.reload()));
  }

  // ── Folder download ────────────────────────────────────────────────────────

  Future<void> _startFolderDownload(
      BuildContext context, FileEntry folderEntry) async {
    FolderListing? listing;
    try {
      listing =
          await ref.read(apiServiceProvider).getFolderListing(folderEntry.path);
    } catch (_) {}

    if (!context.mounted) return;

    if (listing == null || listing.entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folder is empty')));
      return;
    }

    final files =
        listing.entries.where((e) => e.type != FileType.folder).toList();
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No files to download (folder only contains subfolders)')));
      return;
    }

    for (final file in files) {
      _startDownload(file.path, file.name);
    }
  }

  Future<void> _setItemAsBackground(BuildContext context, _BrowserItem item,
      FolderListing listing) async {
    final e = item.entry;
    final notifier = ref.read(_browserNotifierProvider.notifier);
    if (_isVideoPath(e.path)) {
      final videoUri = item.streamUri ??
          await ref.read(apiServiceProvider).buildStreamUriWithToken(e.path);
      if (!context.mounted) return;
      final result = await context.push<BackgroundVideoTrimResult>(
        '/background-video-trim',
        extra: {'videoUri': videoUri, 'videoPath': e.path},
      );
      if (result != null) {
        await notifier.setBackgroundVideo(
          result.videoPath,
          loopStartMs: result.loopStartMs,
          loopEndMs: result.loopEndMs,
        );
      }
    } else {
      final imageUri = item.streamUri ??
          await ref.read(apiServiceProvider).buildStreamUriWithToken(e.path);
      if (!context.mounted) return;
      final result = await context.push<BackgroundCropResult>(
        '/background-crop?imagePath=${Uri.encodeComponent(e.path)}',
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
  }
}

// --- Properties dialog ---

class _PropertiesDialog extends StatefulWidget {
  const _PropertiesDialog({required this.entry, required this.ref});
  final FileEntry entry;
  final WidgetRef ref;

  @override
  State<_PropertiesDialog> createState() => _PropertiesDialogState();
}

class _PropertiesDialogState extends State<_PropertiesDialog> {
  int? _folderItemCount;
  bool _loadingCount = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry.type == FileType.folder) {
      _loadFolderCount();
    }
  }

  Future<void> _loadFolderCount() async {
    setState(() => _loadingCount = true);
    try {
      final listing = await widget.ref
          .read(apiServiceProvider)
          .getFolderListing(widget.entry.path);
      if (mounted) {
        setState(() {
          _folderItemCount = listing?.entries.length;
          _loadingCount = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final modified = '${e.lastModified.year}-'
        '${e.lastModified.month.toString().padLeft(2, '0')}-'
        '${e.lastModified.day.toString().padLeft(2, '0')}  '
        '${e.lastModified.hour.toString().padLeft(2, '0')}:'
        '${e.lastModified.minute.toString().padLeft(2, '0')}';

    final rows = <_PropRow>[
      _PropRow('Name', e.name),
      _PropRow('Type', e.type.name[0].toUpperCase() + e.type.name.substring(1)),
      if (e.type != FileType.folder && e.sizeBytes > 0)
        _PropRow('Size', FileSizeFormatter.format(e.sizeBytes)),
      if (e.type == FileType.folder)
        _PropRow(
          'Items',
          _loadingCount
              ? 'Loading…'
              : _folderItemCount != null
                  ? '$_folderItemCount items'
                  : '—',
        ),
      _PropRow('Modified', modified),
    ];

    return AlertDialog(
      title: Row(children: [
        Icon(_iconForType(e.type), color: cs.primary, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Properties',
              style: tt.titleMedium, overflow: TextOverflow.ellipsis),
        ),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(r.label,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ),
                      Expanded(
                        child: Text(r.value,
                            style: tt.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  IconData _iconForType(FileType type) => switch (type) {
        FileType.folder => Icons.folder,
        FileType.video => Icons.videocam,
        FileType.image => Icons.image,
        FileType.audio => Icons.audio_file,
        FileType.document => Icons.description,
        FileType.archive => Icons.folder_zip,
        _ => Icons.insert_drive_file,
      };
}

class _PropRow {
  const _PropRow(this.label, this.value);
  final String label;
  final String value;
}

// --- Sub-widgets ---

class _DensityToolbar extends StatelessWidget {
  const _DensityToolbar({
    required this.count,
    required this.density,
    required this.sort,
    required this.onCycle,
    required this.onSort,
    this.hasBackground = false,
  });
  final int count;
  final GridDensity density;
  final SortOption sort;
  final VoidCallback onCycle;
  final ValueChanged<SortOption> onSort;
  final bool hasBackground;

  Future<void> _showSortSheet(BuildContext context) async {
    final chosen = await showModalBottomSheet<SortOption>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Sort by',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            const Divider(height: 1),
            ...SortOption.values.map((opt) => ListTile(
                  title: Text(sortLabel(opt)),
                  trailing: sort == opt
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.pop(context, opt),
                )),
          ],
        ),
      ),
    );
    if (chosen != null) onSort(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final fgColor = hasBackground ? Colors.white : null;
    final style = hasBackground
        ? Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)
        : Theme.of(context).textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text('$count items', style: style),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _showSortSheet(context),
            style: hasBackground
                ? TextButton.styleFrom(foregroundColor: fgColor)
                : null,
            icon: const Icon(Icons.sort, size: 18),
            label: Text(sortLabel(sort)),
          ),
          TextButton.icon(
            onPressed: onCycle,
            style: hasBackground
                ? TextButton.styleFrom(foregroundColor: fgColor)
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
              : Center(child: Icon(icon, size: 48, color: cs.primary)),
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
              if (isSelected) const ColoredBox(color: Color(0x4400AAFF)),
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
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHigh
                .withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected
                    ? Colors.lightBlue
                    : Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.4),
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
