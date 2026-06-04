import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/bookmarked_folder.dart';
import '../../core/models/file_entry.dart';
import '../../core/models/folder_listing.dart';
import '../../core/utils/grid_density_helper.dart';
import '../../core/utils/sort_helper.dart';
import '../../providers/dashboard_providers.dart' show bookmarksProvider;
import '../../providers/services_providers.dart';

// ─── Data ────────────────────────────────────────────────────────────────────

class _PaneEntry {
  const _PaneEntry({required this.entry, this.thumbnailUri, this.streamUri});
  final FileEntry entry;
  final String? thumbnailUri;
  final String? streamUri;
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class SplitBrowserScreen extends ConsumerStatefulWidget {
  const SplitBrowserScreen({
    super.key,
    required this.path1,
    required this.path2,
  });
  final String path1;
  final String path2;

  @override
  ConsumerState<SplitBrowserScreen> createState() => _SplitBrowserScreenState();
}

class _SplitBrowserScreenState extends ConsumerState<SplitBrowserScreen> {
  final _pane1Key = GlobalKey<_BrowserPaneState>();
  final _pane2Key = GlobalKey<_BrowserPaneState>();

  // Flex weights for each pane; must sum to 100
  final List<double> _weights = [50, 50];

  // null = auto (wide → horizontal); true/false = forced
  bool? _isHorizontalOverride;

  bool _isHorizontal(BuildContext ctx) {
    if (_isHorizontalOverride != null) return _isHorizontalOverride!;
    final size = MediaQuery.sizeOf(ctx);
    return size.width >= size.height;
  }

  void _closePane(int paneIndex) {
    final remaining = paneIndex == 0
        ? (_pane2Key.currentState?.currentPath ?? widget.path2)
        : (_pane1Key.currentState?.currentPath ?? widget.path1);
    context.pop();
    // Reopen browse at the surviving pane's current path
    final ts = DateTime.now().millisecondsSinceEpoch;
    context.go('/browse?path=${Uri.encodeComponent(remaining)}&t=$ts');
  }

  Widget _buildDivider(bool horizontal) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final total = horizontal ? box.size.width : box.size.height;
        final delta = horizontal ? d.delta.dx : d.delta.dy;
        setState(() {
          _weights[0] = (_weights[0] + delta / total * 100).clamp(20, 80);
          _weights[1] = 100 - _weights[0];
        });
      },
      child: horizontal
          ? MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: Container(
                width: 6,
                color: Theme.of(context).dividerColor,
              ),
            )
          : MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              child: Container(
                height: 6,
                color: Theme.of(context).dividerColor,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = _isHorizontal(context);
    final pane1 = _BrowserPaneWidget(
      key: _pane1Key,
      initialPath: widget.path1,
      onClose: () => _closePane(0),
      onOpenInOtherPane: (path) =>
          _pane2Key.currentState?.navigateTo(path),
    );
    final pane2 = _BrowserPaneWidget(
      key: _pane2Key,
      initialPath: widget.path2,
      onClose: () => _closePane(1),
      onOpenInOtherPane: (path) =>
          _pane1Key.currentState?.navigateTo(path),
    );

    final body = horizontal
        ? Row(children: [
            Expanded(
                flex: _weights[0].round(),
                child: pane1),
            _buildDivider(true),
            Expanded(
                flex: _weights[1].round(),
                child: pane2),
          ])
        : Column(children: [
            Expanded(
                flex: _weights[0].round(),
                child: pane1),
            _buildDivider(false),
            Expanded(
                flex: _weights[1].round(),
                child: pane2),
          ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split View'),
        actions: [
          IconButton(
            icon: Icon(horizontal
                ? Icons.horizontal_split
                : Icons.vertical_split),
            tooltip: horizontal ? 'Switch to vertical' : 'Switch to horizontal',
            onPressed: () =>
                setState(() => _isHorizontalOverride = !horizontal),
          ),
        ],
      ),
      body: body,
    );
  }
}

// ─── Pane ─────────────────────────────────────────────────────────────────────

class _BrowserPaneWidget extends ConsumerStatefulWidget {
  const _BrowserPaneWidget({
    super.key,
    required this.initialPath,
    required this.onClose,
    required this.onOpenInOtherPane,
  });
  final String initialPath;
  final VoidCallback onClose;
  final void Function(String path) onOpenInOtherPane;

  @override
  ConsumerState<_BrowserPaneWidget> createState() => _BrowserPaneState();
}

class _BrowserPaneState extends ConsumerState<_BrowserPaneWidget> {
  final _history = <String>[];
  FolderListing? _listing;
  List<_PaneEntry> _items = [];
  GridDensity _density = GridDensity.normal;
  SortOption _sort = SortOption.nameAsc;
  bool _loading = false;
  bool _isBookmarked = false;
  String? _error;

  String get currentPath =>
      _history.isNotEmpty ? _history.last : widget.initialPath;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    _density =
        GridDensityHelper.fromString(prefs.getString('grid_density') ?? 'normal');
    _sort = sortFromString(prefs.getString(sortPrefKey));
    _navigateTo(widget.initialPath);
  }

  Future<void> _navigateTo(String path, {bool addToHistory = true}) async {
    if (addToHistory) _history.add(path);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final quality =
          ref.read(sharedPrefsProvider).getInt('thumbnail_quality') ?? 50;

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
          if (addToHistory) {
            _history.last = roots.first.path;
          } else {
            _history
              ..clear()
              ..add(roots.first.path);
          }
        } else {
          listing = FolderListing(
            path: '',
            parentPath: null,
            displayName: 'Drives',
            entries: roots
                .map((r) => FileEntry(
                      name: r.name,
                      path: r.path,
                      type: FileType.folder,
                      sizeBytes: 0,
                      lastModified: DateTime.fromMillisecondsSinceEpoch(0),
                      hasThumbnail: false,
                    ))
                .toList(),
          );
        }
      } else {
        final l = await api.getFolderListing(path);
        if (l == null) throw Exception('Could not load folder.');
        listing = l;
      }

      final sorted = applySortToEntries(listing.entries, _sort);
      final items = <_PaneEntry>[];
      for (final e in sorted) {
        final thumb = e.hasThumbnail
            ? await api.buildThumbnailUriWithToken(e.path, quality: quality)
            : null;
        final stream =
            (e.type == FileType.video || e.type == FileType.image)
                ? await api.buildStreamUriWithToken(e.path)
                : null;
        items.add(_PaneEntry(entry: e, thumbnailUri: thumb, streamUri: stream));
      }

      final bSvc = ref.read(bookmarkServiceProvider);
      final bookmarked = bSvc.isBookmarked(listing.path);

      if (!mounted) return;
      setState(() {
        _listing = listing;
        _items = items;
        _isBookmarked = bookmarked;
        _loading = false;
      });
    } catch (err) {
      if (mounted) setState(() { _error = err.toString(); _loading = false; });
    }
  }

  // Public: called from sibling pane via GlobalKey
  void navigateTo(String path) => _navigateTo(path);

  void _goBack() {
    if (_history.length <= 1) return;
    _history.removeLast();
    _navigateTo(_history.removeLast());
  }

  Future<void> _toggleBookmark() async {
    final listing = _listing;
    if (listing == null) return;
    final svc = ref.read(bookmarkServiceProvider);
    if (_isBookmarked) {
      await svc.removeBookmark(listing.path);
    } else {
      await svc.addBookmark(
          BookmarkedFolder(path: listing.path, displayName: listing.displayName));
    }
    ref.invalidate(bookmarksProvider);
    if (mounted) setState(() => _isBookmarked = !_isBookmarked);
  }

  void _cycleDensity() {
    final next = GridDensityHelper.next(_density);
    ref.read(sharedPrefsProvider).setString('grid_density', next.name);
    setState(() => _density = next);
  }

  void _cycleSortWith(SortOption chosen) {
    ref.read(sharedPrefsProvider).setString(sortPrefKey, chosen.name);
    if (_listing == null) {
      setState(() => _sort = chosen);
      return;
    }
    final sorted = applySortToEntries(
        _items.map((i) => i.entry).toList(), chosen);
    final uriMap = {for (final i in _items) i.entry.path: i};
    setState(() {
      _sort = chosen;
      _items =
          sorted.map((e) => uriMap[e.path] ?? _PaneEntry(entry: e)).toList();
    });
  }

  Future<void> _showSortSheet() async {
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
                  trailing: _sort == opt
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.pop(context, opt),
                )),
          ],
        ),
      ),
    );
    if (chosen != null) _cycleSortWith(chosen);
  }

  Future<void> _onTap(_PaneEntry item) async {
    final e = item.entry;
    if (e.type == FileType.folder) {
      _navigateTo(e.path);
    } else if (e.type == FileType.image || e.type == FileType.video) {
      if (_listing == null || !context.mounted) return;
      final media = _listing!.entries
          .where((x) => x.type == FileType.image || x.type == FileType.video)
          .toList();
      final idx = media.indexWhere((x) => x.path == e.path);
      context.push(
          '/gallery?path=${Uri.encodeComponent(_listing!.path)}&index=${idx < 0 ? 0 : idx}');
    }
  }

  Future<void> _onLongPress(_PaneEntry item) async {
    final e = item.entry;
    final actions = <String, String>{};

    if (e.type == FileType.folder) {
      actions['open'] = 'Open in this pane';
      actions['open_other'] = 'Open in other pane';
      actions['bookmark'] = 'Bookmark folder';
    } else if (e.type == FileType.video) {
      actions['play'] = 'Play';
    } else if (e.type == FileType.image) {
      actions['view'] = 'View';
    }

    if (!context.mounted) return;
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
                  leading: Icon(_paneActionIcon(kv.key)),
                  title: Text(kv.value),
                  onTap: () => Navigator.pop(context, kv.key),
                )),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        _navigateTo(e.path);
      case 'open_other':
        widget.onOpenInOtherPane(e.path);
      case 'bookmark':
        final svc = ref.read(bookmarkServiceProvider);
        await svc.addBookmark(
            BookmarkedFolder(path: e.path, displayName: e.name));
        ref.invalidate(bookmarksProvider);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Bookmarked ${e.name}')));
        }
      case 'play':
        if (_listing != null && mounted) {
          final media = _listing!.entries
              .where((x) => x.type == FileType.image || x.type == FileType.video)
              .toList();
          final idx = media.indexWhere((x) => x.path == e.path);
          context.push(
              '/gallery?path=${Uri.encodeComponent(_listing!.path)}&index=${idx < 0 ? 0 : idx}');
        }
      case 'view':
        if (_listing != null && mounted) {
          final media = _listing!.entries
              .where(
                  (x) => x.type == FileType.image || x.type == FileType.video)
              .toList();
          final idx = media.indexWhere((x) => x.path == e.path);
          context.push(
              '/gallery?path=${Uri.encodeComponent(_listing!.path)}&index=${idx < 0 ? 0 : idx}');
        }
    }
  }

  IconData _paneActionIcon(String key) => switch (key) {
        'open' => Icons.folder_open,
        'open_other' => Icons.adaptive.share,
        'bookmark' => Icons.bookmark_add_outlined,
        'play' => Icons.play_arrow_rounded,
        'view' => Icons.image_outlined,
        _ => Icons.more_horiz,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PaneHeader(
          title: _listing?.displayName ?? '…',
          canGoBack: _history.length > 1,
          isBookmarked: _isBookmarked,
          density: _density,
          onBack: _history.length > 1 ? _goBack : null,
          onBookmark: _toggleBookmark,
          onCycleDensity: _cycleDensity,
          onSort: _showSortSheet,
          onClose: widget.onClose,
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _navigateTo(currentPath, addToHistory: false),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty && !_loading) {
      return const Center(child: Text('Empty folder'));
    }

    return LayoutBuilder(builder: (ctx, constraints) {
      final dynamicCols = GridDensityHelper.getColumnCount(
          constraints.maxWidth, _density);
      return GridView.builder(
        padding: const EdgeInsets.all(6),
        // ignore: deprecated_member_use
        cacheExtent: 400,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: dynamicCols,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 0.85,
        ),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final item = _items[i];
          return _PaneGridItem(
            item: item,
            onTap: () => _onTap(item),
            onLongPress: () => _onLongPress(item),
          );
        },
      );
    });
  }
}

// ─── Pane header ──────────────────────────────────────────────────────────────

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({
    required this.title,
    required this.canGoBack,
    required this.isBookmarked,
    required this.density,
    required this.onBack,
    required this.onBookmark,
    required this.onCycleDensity,
    required this.onSort,
    required this.onClose,
  });

  final String title;
  final bool canGoBack;
  final bool isBookmarked;
  final GridDensity density;
  final VoidCallback? onBack;
  final VoidCallback onBookmark;
  final VoidCallback onCycleDensity;
  final VoidCallback onSort;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      child: Row(
        children: [
          // Back button
          if (canGoBack)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: onBack,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            )
          else
            const SizedBox(width: 8),
          // Folder name
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          // Bookmark
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
              size: 18,
              color: cs.primary,
            ),
            onPressed: onBookmark,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
          // Sort
          IconButton(
            icon: const Icon(Icons.sort, size: 18),
            onPressed: onSort,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
          // Density cycle
          IconButton(
            icon: Icon(
              GridDensityHelper.icon(density),
              size: 18,
            ),
            onPressed: onCycleDensity,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
          // Close pane ×
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
            tooltip: 'Close pane',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ],
      ),
    );
  }
}

// ─── Grid item ────────────────────────────────────────────────────────────────

class _PaneGridItem extends StatelessWidget {
  const _PaneGridItem({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });
  final _PaneEntry item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static IconData _iconFor(FileType t) => switch (t) {
        FileType.folder => Icons.folder_outlined,
        FileType.video => Icons.videocam_outlined,
        FileType.image => Icons.image_outlined,
        FileType.audio => Icons.music_note_outlined,
        FileType.document => Icons.description_outlined,
        FileType.archive => Icons.folder_zip_outlined,
        _ => Icons.insert_drive_file_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = item.entry;
    final icon = _iconFor(e.type);

    return Card(
      margin: EdgeInsets.zero,
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
                      memCacheWidth: 240,
                      placeholder: (_, __) =>
                          Center(child: Icon(icon, size: 32, color: cs.outline)),
                      errorWidget: (_, __, ___) =>
                          Center(child: Icon(icon, size: 32, color: cs.outline)),
                    )
                  : Center(child: Icon(icon, size: 36, color: cs.primary)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Text(
                e.name,
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
}
