import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/media_types.dart';
import '../../core/models/bookmarked_folder.dart';
import '../../core/models/file_entry.dart';
import '../../core/models/folder_listing.dart';
import '../../core/models/folder_prefs.dart';
import '../../core/utils/grid_density_helper.dart';
import '../../providers/services_providers.dart';
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
  });
  final FolderListing? listing;
  final List<_BrowserItem> items;
  final FolderPrefs prefs;
  final bool isBookmarked;
  final GridDensity density;
  final bool canNavigateBack;
  // Full http://host/stream/...?token=... URI, ready for CachedNetworkImage
  final String? backgroundImageUri;

  _BrowserState copyWith({
    FolderListing? listing,
    List<_BrowserItem>? items,
    FolderPrefs? prefs,
    bool? isBookmarked,
    GridDensity? density,
    bool? canNavigateBack,
    String? backgroundImageUri,
    bool clearBackgroundUri = false,
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
      );
}

// --- Providers ---

final _browserPathProvider = Provider.autoDispose<String>((ref) => '');

class _BrowserNotifier extends AutoDisposeAsyncNotifier<_BrowserState> {
  final _history = <String>[];

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
    state = const AsyncLoading<_BrowserState>().copyWithPrevious(state);
    _history.add(path);
    state = await AsyncValue.guard(() => _load(path));
  }

  Future<void> navigateBack() async {
    if (_history.length <= 1) return;
    _history.removeLast();
    state = const AsyncLoading<_BrowserState>().copyWithPrevious(state);
    final result = await AsyncValue.guard(() => _load(_history.last));
    // If we've reached the start of history but the loaded folder still has a parent,
    // lazily extend history so the user can keep navigating back (handles deep bookmarks).
    if (_history.length == 1 && result.hasValue) {
      final parentPath = result.requireValue.listing?.parentPath;
      if (parentPath != null && parentPath.isNotEmpty) {
        _history.insert(0, parentPath);
        state = AsyncData(result.requireValue.copyWith(canNavigateBack: true));
        return;
      }
    }
    state = result;
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

  Future<void> setBackgroundImage(String serverPath) async {
    final s = state.valueOrNull;
    if (s?.listing == null) return;
    final updated = s!.prefs.copyWith(backgroundImagePath: serverPath);
    await ref
        .read(folderPrefsServiceProvider)
        .savePrefs(s.listing!.path, updated);
    final uri = await ref.read(apiServiceProvider).buildStreamUriWithToken(serverPath);
    state = AsyncData(s.copyWith(prefs: updated, backgroundImageUri: uri));
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
    return ref.watch(_browserNotifierProvider).when(
          skipLoadingOnReload: true,
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, _) => Scaffold(
              appBar: AppBar(), body: Center(child: Text('Error: $err'))),
          data: (s) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _BrowserLoaded(
              key: ValueKey(s.listing?.path ?? ''),
              state: s,
            ),
          ),
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

    return Scaffold(
      appBar: AppBar(
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
                state.isBookmarked ? Icons.bookmark : Icons.bookmark_outline),
            onPressed: notifier.toggleBookmark,
          ),
          if (state.prefs.backgroundImagePath != null)
            IconButton(
              icon: const Icon(Icons.wallpaper),
              tooltip: 'Clear background',
              onPressed: notifier.clearBackgroundImage,
            )
          else
            IconButton(
              icon: const Icon(Icons.image_outlined),
              tooltip: 'Set background',
              onPressed: () async {
                final picked = await context.push<String>(
                    '/image-picker?path=${Uri.encodeComponent(listing.path)}');
                if (picked != null) await notifier.setBackgroundImage(picked);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (state.backgroundImageUri != null)
            _BackgroundBanner(
                imageUri: state.backgroundImageUri!,
                title: listing.displayName),
          _DensityToolbar(
              count: state.items.length,
              density: state.density,
              onCycle: notifier.cycleDensity),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final cols = GridDensityHelper.getColumnCount(
                  constraints.maxWidth, state.density);
              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.85,
                ),
                itemCount: state.items.length,
                itemBuilder: (context, i) => _FileGridItem(
                  item: state.items[i],
                  onTap: () => _onTap(context, ref, state.items[i]),
                  onLongPress: () =>
                      _onLongPress(context, ref, state.items[i], listing),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context, WidgetRef ref, _BrowserItem item) {
    final e = item.entry;
    switch (e.type) {
      case FileType.folder:
        ref.read(_browserNotifierProvider.notifier).navigateTo(e.path);
      case FileType.video:
        context.push(
            '/player?path=${Uri.encodeComponent(e.path)}&name=${Uri.encodeComponent(e.name)}');
      case FileType.image:
        final listing = ref.read(_browserNotifierProvider).valueOrNull?.listing;
        final images =
            listing?.entries.where((x) => x.type == FileType.image).toList() ??
                [];
        final idx = images.indexWhere((x) => x.path == e.path);
        context.push(
            '/gallery?path=${Uri.encodeComponent(listing?.path ?? '')}&index=${idx < 0 ? 0 : idx}');
      default:
        break;
    }
  }

  Future<void> _onLongPress(BuildContext context, WidgetRef ref,
      _BrowserItem item, FolderListing listing) async {
    final e = item.entry;
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
        final images =
            listing.entries.where((x) => x.type == FileType.image).toList();
        final idx = images.indexWhere((x) => x.path == e.path);
        context.push(
            '/gallery?path=${Uri.encodeComponent(listing.path)}&index=${idx < 0 ? 0 : idx}');
    }
  }
}

// --- Sub-widgets ---

class _BackgroundBanner extends StatelessWidget {
  const _BackgroundBanner({required this.imageUri, required this.title});
  final String imageUri;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(imageUrl: imageUri, fit: BoxFit.cover),
          Container(color: Colors.black54),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DensityToolbar extends StatelessWidget {
  const _DensityToolbar(
      {required this.count, required this.density, required this.onCycle});
  final int count;
  final GridDensity density;
  final VoidCallback onCycle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text('$count items',
              style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          TextButton.icon(
            onPressed: onCycle,
            icon: const Icon(Icons.grid_view, size: 18),
            label: Text(GridDensityHelper.label(density)),
          ),
        ],
      ),
    );
  }
}

class _FileGridItem extends StatelessWidget {
  const _FileGridItem(
      {required this.item, required this.onTap, required this.onLongPress});
  final _BrowserItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entry = item.entry;
    final icon = _iconFor(entry.type);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          children: [
            Expanded(
              child: item.thumbnailUri != null
                  ? CachedNetworkImage(
                      imageUrl: item.thumbnailUri!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) =>
                          Center(child: Icon(icon, size: 40, color: cs.outline)),
                      errorWidget: (_, __, ___) =>
                          Center(child: Icon(icon, size: 40, color: cs.outline)),
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
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
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
