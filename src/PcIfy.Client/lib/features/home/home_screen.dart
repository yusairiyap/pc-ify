import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/bookmarked_folder.dart';
import '../../core/models/file_entry.dart';
import '../../core/models/folder_prefs.dart';
import '../../providers/services_providers.dart';
import '../../widgets/folder_background_image.dart';
import '../../widgets/video_background_player.dart';
import '../browser/background_crop_screen.dart';
import '../browser/background_video_trim_screen.dart';

final bookmarksProvider = Provider<List<BookmarkedFolder>>((ref) {
  return ref.watch(bookmarkServiceProvider).getBookmarks();
});

final _bookmarkThumbnailsProvider =
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

const _homePrefsKey = '__home__';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  FolderPrefs _prefs = const FolderPrefs();
  String? _backgroundImageUri;
  String? _backgroundVideoUri;
  ProviderSubscription<int>? _prefsVersionSub;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadBackground);
    // Reload background whenever folder prefs are bulk-changed (e.g. backup restore).
    _prefsVersionSub = ref.listenManual(
      folderPrefsVersionProvider,
      (previous, next) {
        if (previous != null && next != previous) _loadBackground();
      },
      fireImmediately: false,
    );
  }

  @override
  void dispose() {
    _prefsVersionSub?.close();
    super.dispose();
  }

  Future<void> _loadBackground() async {
    final prefs =
        await ref.read(folderPrefsServiceProvider).getPrefs(_homePrefsKey);
    if (!mounted) return;
    String? imageUri;
    if (prefs.backgroundImagePath != null) {
      imageUri = await ref
          .read(apiServiceProvider)
          .buildStreamUriWithToken(prefs.backgroundImagePath!);
    }
    String? videoUri;
    if (prefs.backgroundVideoPath != null) {
      videoUri = await ref
          .read(apiServiceProvider)
          .buildStreamUriWithToken(prefs.backgroundVideoPath!);
    }
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _backgroundImageUri = imageUri;
      _backgroundVideoUri = videoUri;
    });
  }

  Future<void> _onBackgroundTap() async {
    if (_prefs.hasBackground) {
      final isVideo = _prefs.isVideoBackground;
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
      if (!mounted || action == null) return;
      if (action == 'remove') {
        await _clearBackground();
        return;
      }
      if (action == 'adjust') {
        final existingPath = _prefs.backgroundImagePath!;
        final imageUri = await ref
            .read(apiServiceProvider)
            .buildStreamUriWithToken(existingPath);
        if (!mounted) return;
        final result = await context.push<BackgroundCropResult>(
          '/background-crop?imagePath=${Uri.encodeComponent(existingPath)}',
          extra: imageUri,
        );
        if (result != null) await _saveImageBackground(result);
        return;
      }
      if (action == 'trim') {
        final existingPath = _prefs.backgroundVideoPath!;
        final videoUri = await ref
            .read(apiServiceProvider)
            .buildStreamUriWithToken(existingPath);
        if (!mounted) return;
        final result = await context.push<BackgroundVideoTrimResult>(
          '/background-video-trim',
          extra: {
            'videoUri': videoUri,
            'videoPath': existingPath,
            'startMs': _prefs.videoLoopStartMs,
            'endMs': _prefs.videoLoopEndMs,
          },
        );
        if (result != null) await _saveVideoBackground(result);
        return;
      }
      // 'change' falls through to picker
    }
    final existingPath =
        _prefs.backgroundImagePath ?? _prefs.backgroundVideoPath;
    final pickerStart = existingPath != null ? _parentOf(existingPath) : '';
    final picked = await context
        .push<String>('/image-picker?path=${Uri.encodeComponent(pickerStart)}');
    if (picked == null || !mounted) return;

    if (_isVideoPath(picked)) {
      final videoUri =
          await ref.read(apiServiceProvider).buildStreamUriWithToken(picked);
      if (!mounted) return;
      final result = await context.push<BackgroundVideoTrimResult>(
        '/background-video-trim',
        extra: {'videoUri': videoUri, 'videoPath': picked},
      );
      if (result != null) await _saveVideoBackground(result);
    } else {
      final imageUri =
          await ref.read(apiServiceProvider).buildStreamUriWithToken(picked);
      if (!mounted) return;
      final result = await context.push<BackgroundCropResult>(
        '/background-crop?imagePath=${Uri.encodeComponent(picked)}',
        extra: imageUri,
      );
      if (result != null) await _saveImageBackground(result);
    }
  }

  Future<void> _saveImageBackground(BackgroundCropResult result) async {
    final updated = FolderPrefs(
      backgroundImagePath: result.imagePath,
      cropOffsetDx: result.cropOffsetDx,
      cropOffsetDy: result.cropOffsetDy,
      cropScale: result.cropScale,
    );
    await ref
        .read(folderPrefsServiceProvider)
        .savePrefs(_homePrefsKey, updated);
    final uri = await ref
        .read(apiServiceProvider)
        .buildStreamUriWithToken(result.imagePath);
    if (!mounted) return;
    setState(() {
      _prefs = updated;
      _backgroundImageUri = uri;
      _backgroundVideoUri = null;
    });
  }

  Future<void> _saveVideoBackground(BackgroundVideoTrimResult result) async {
    final updated = FolderPrefs(
      backgroundVideoPath: result.videoPath,
      videoLoopStartMs: result.loopStartMs,
      videoLoopEndMs: result.loopEndMs,
    );
    await ref
        .read(folderPrefsServiceProvider)
        .savePrefs(_homePrefsKey, updated);
    final uri = await ref
        .read(apiServiceProvider)
        .buildStreamUriWithToken(result.videoPath);
    if (!mounted) return;
    setState(() {
      _prefs = updated;
      _backgroundImageUri = null;
      _backgroundVideoUri = uri;
    });
  }

  Future<void> _clearBackground() async {
    final updated = _prefs.copyWith(clearBackground: true);
    await ref
        .read(folderPrefsServiceProvider)
        .savePrefs(_homePrefsKey, updated);
    if (!mounted) return;
    setState(() {
      _prefs = updated;
      _backgroundImageUri = null;
      _backgroundVideoUri = null;
    });
  }

  bool _isVideoPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return {
      'mp4',
      'mkv',
      'mov',
      'avi',
      'wmv',
      'webm',
      'm4v',
      'ts',
      'flv',
      'mpeg',
      'mpg'
    }.contains(ext);
  }

  String _parentOf(String path) {
    final i = path.lastIndexOf('/');
    if (i > 0) return path.substring(0, i);
    final j = path.lastIndexOf('\\');
    if (j > 0) return path.substring(0, j);
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = ref.watch(bookmarksProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasBg = _backgroundImageUri != null || _backgroundVideoUri != null;

    final appBar = AppBar(
      backgroundColor: hasBg ? Colors.transparent : null,
      foregroundColor: hasBg ? Colors.white : null,
      elevation: hasBg ? 0 : null,
      title: const Text('Home'),
      actions: [
        IconButton(
          icon: Icon(
            _prefs.hasBackground ? Icons.wallpaper : Icons.image_outlined,
            color: hasBg ? Colors.white : cs.primary,
          ),
          tooltip:
              _prefs.hasBackground ? 'Background options' : 'Set background',
          onPressed: _onBackgroundTap,
        ),
        IconButton(
          icon:
              Icon(Icons.folder_open, color: hasBg ? Colors.white : cs.primary),
          tooltip: 'Browse All',
          onPressed: () => context.go('/browse'),
        ),
      ],
    );

    final body = bookmarks.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_outline,
                    size: 72, color: hasBg ? Colors.white54 : cs.outline),
                const SizedBox(height: 16),
                Text('No bookmarks yet',
                    style: tt.titleMedium
                        ?.copyWith(color: hasBg ? Colors.white : null)),
                const SizedBox(height: 8),
                Text(
                  'Browse folders and bookmark them for quick access.',
                  textAlign: TextAlign.center,
                  style: tt.bodySmall
                      ?.copyWith(color: hasBg ? Colors.white70 : cs.outline),
                ),
              ],
            ),
          )
        : CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Text(
                    'My Bookmarks',
                    style: tt.labelMedium?.copyWith(
                      color: hasBg ? Colors.white70 : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.82,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final b = bookmarks[i];
                      return _BookmarkCard(
                        bookmark: b,
                        hasBackground: hasBg,
                        onTap: () => context.go(
                          '/browse?path=${Uri.encodeComponent(b.path)}'
                          '&t=${DateTime.now().millisecondsSinceEpoch}',
                        ),
                        onRemove: () {
                          ref
                              .read(bookmarkServiceProvider)
                              .removeBookmark(b.path);
                          ref.invalidate(bookmarksProvider);
                        },
                      );
                    },
                    childCount: bookmarks.length,
                  ),
                ),
              ),
            ],
          );

    if (hasBg) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_backgroundVideoUri != null)
              VideoBackgroundPlayer(
                  videoUri: _backgroundVideoUri!, prefs: _prefs)
            else
              FolderBackgroundImage(
                  imageUri: _backgroundImageUri!, prefs: _prefs),
            DecoratedBox(
              decoration:
                  BoxDecoration(color: Colors.black.withValues(alpha: 0.35)),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.viewPaddingOf(context).top + kToolbarHeight,
              ),
              child: body,
            ),
          ],
        ),
      );
    }

    return Scaffold(appBar: appBar, body: body);
  }
}

class _BookmarkCard extends ConsumerWidget {
  const _BookmarkCard({
    required this.bookmark,
    required this.onTap,
    required this.onRemove,
    this.hasBackground = false,
  });

  final BookmarkedFolder bookmark;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool hasBackground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final thumbsAsync = ref.watch(_bookmarkThumbnailsProvider(bookmark.path));

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        onLongPress: () async {
          final action = await showModalBottomSheet<String>(
            context: context,
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Remove bookmark'),
                    onTap: () => Navigator.pop(context, 'remove'),
                  ),
                ],
              ),
            ),
          );
          if (action == 'remove') onRemove();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: thumbsAsync.when(
                data: (urls) => urls.isEmpty
                    ? _FolderPlaceholder(cs: cs)
                    : _ThumbnailStack(urls: urls, cs: cs),
                loading: () => _FolderPlaceholder(cs: cs),
                error: (_, __) => _FolderPlaceholder(cs: cs),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Text(
                bookmark.displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: hasBackground ? Colors.white : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderPlaceholder extends StatelessWidget {
  const _FolderPlaceholder({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.folder_rounded, size: 52, color: cs.primary),
    );
  }
}

class _ThumbnailStack extends StatelessWidget {
  const _ThumbnailStack({required this.urls, required this.cs});

  final List<String> urls;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final layers = <Widget>[];

    // Furthest back card — tilted left
    if (urls.length >= 3) {
      layers.add(_card(urls[2], angle: -0.20, tx: -12.0, ty: 6.0));
    }

    // Middle card — tilted right
    if (urls.length >= 2) {
      layers.add(_card(urls[1], angle: 0.16, tx: 12.0, ty: 4.0));
    }

    // Front card — upright with shadow
    layers.add(_card(urls[0], angle: 0, tx: 0, ty: 0, isFront: true));

    return Stack(
      alignment: Alignment.center,
      children: layers,
    );
  }

  Widget _card(
    String url, {
    required double angle,
    required double tx,
    required double ty,
    bool isFront = false,
  }) {
    return Transform.translate(
      offset: Offset(tx, ty),
      child: Transform.rotate(
        angle: angle,
        alignment: Alignment.center,
        child: FractionallySizedBox(
          widthFactor: 0.78,
          heightFactor: 0.82,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isFront ? 0.40 : 0.20),
                  blurRadius: isFront ? 12 : 5,
                  spreadRadius: isFront ? 1 : 0,
                  offset: Offset(0, isFront ? 5 : 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: cs.outline,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
