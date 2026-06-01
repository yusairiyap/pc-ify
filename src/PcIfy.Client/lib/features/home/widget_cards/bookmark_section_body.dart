import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/bookmarked_folder.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/services_providers.dart';

class BookmarkSectionBody extends ConsumerStatefulWidget {
  const BookmarkSectionBody({super.key, required this.hasBg});
  final bool hasBg;

  @override
  ConsumerState<BookmarkSectionBody> createState() => _BookmarkSectionBodyState();
}

class _BookmarkSectionBodyState extends ConsumerState<BookmarkSectionBody> {
  List<BookmarkedFolder>? _items;
  int? _draggingIndex;
  int? _hoverIndex;

  void _syncItems(List<BookmarkedFolder> bookmarks) {
    if (_draggingIndex == null) {
      _items = List.from(bookmarks);
    }
  }

  void _moveItem(int from, int to) {
    if (from == to) return;
    setState(() {
      final item = _items!.removeAt(from);
      _items!.insert(to, item);
      _draggingIndex = to;
      _hoverIndex = to;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = ref.watch(bookmarksProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Sync items list whenever bookmarks change (but not while dragging)
    _syncItems(bookmarks);
    final items = _items ?? List<BookmarkedFolder>.from(bookmarks);

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline,
                size: 48, color: widget.hasBg ? Colors.white54 : cs.outline),
            const SizedBox(height: 12),
            Text('No bookmarks yet',
                style: tt.titleSmall
                    ?.copyWith(color: widget.hasBg ? Colors.white : null)),
            const SizedBox(height: 6),
            Text(
              'Browse folders and bookmark them for quick access.',
              textAlign: TextAlign.center,
              style: tt.bodySmall
                  ?.copyWith(color: widget.hasBg ? Colors.white70 : cs.outline),
            ),
          ],
        ),
      );
    }

    final crossAxisCount = _crossAxisCount(context);
    final rowCount = (items.length / crossAxisCount).ceil();
    final itemHeight = 160.0 / 0.82;
    final gridHeight = rowCount * (itemHeight + 8);

    return SizedBox(
      height: gridHeight,
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final b = items[i];
                  final isHovered = _hoverIndex == i && _draggingIndex != i;
                  return DragTarget<int>(
                    key: ValueKey(b.path),
                    onWillAcceptWithDetails: (details) {
                      setState(() => _hoverIndex = i);
                      return details.data != i;
                    },
                    onLeave: (_) => setState(() => _hoverIndex = null),
                    onAcceptWithDetails: (details) {
                      _moveItem(details.data, i);
                      setState(() {
                        _draggingIndex = null;
                        _hoverIndex = null;
                      });
                      ref.read(bookmarkServiceProvider).reorder(List.from(items));
                      ref.invalidate(bookmarksProvider);
                    },
                    builder: (context, candidateData, rejectedData) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: isHovered
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: cs.primary,
                                  width: 2,
                                ),
                              )
                            : null,
                        child: LongPressDraggable<int>(
                          data: i,
                          delay: const Duration(milliseconds: 350),
                          onDragStarted: () =>
                              setState(() => _draggingIndex = i),
                          onDragEnd: (_) => setState(() {
                            _draggingIndex = null;
                            _hoverIndex = null;
                          }),
                          feedback: SizedBox(
                            width: 140,
                            height: 140 / 0.82,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(12),
                              child: Opacity(
                                opacity: 0.85,
                                child: BookmarkCard(
                                  bookmark: b,
                                  hasBackground: widget.hasBg,
                                  onTap: () {},
                                  onRemove: () {},
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: BookmarkCard(
                              bookmark: b,
                              hasBackground: widget.hasBg,
                              onTap: () {},
                              onRemove: () {},
                            ),
                          ),
                          child: BookmarkCard(
                            bookmark: b,
                            hasBackground: widget.hasBg,
                            onTap: () => context.go(
                              '/browse?path=${Uri.encodeComponent(b.path)}'
                              '&t=${DateTime.now().millisecondsSinceEpoch}',
                            ),
                            onRemove: () {
                              ref.read(bookmarkServiceProvider).removeBookmark(b.path);
                              ref.invalidate(bookmarksProvider);
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return (width / 160).floor().clamp(2, 6);
  }
}

class BookmarkCard extends ConsumerWidget {
  const BookmarkCard({
    super.key,
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
    final thumbsAsync = ref.watch(bookmarkThumbnailsProvider(bookmark.path));

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
