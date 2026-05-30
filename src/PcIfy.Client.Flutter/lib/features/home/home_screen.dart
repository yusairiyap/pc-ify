import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/bookmarked_folder.dart';
import '../../providers/services_providers.dart';

// Provider that rebuilds when invalidated (after add/remove bookmark)
final bookmarksProvider = Provider<List<BookmarkedFolder>>((ref) {
  return ref.watch(bookmarkServiceProvider).getBookmarks();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/browse'),
            icon: const Icon(Icons.folder_open),
            label: const Text('Browse All'),
          ),
        ],
      ),
      body: bookmarks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_outline, size: 72, color: cs.outline),
                  const SizedBox(height: 16),
                  Text('No bookmarks yet',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Browse folders and bookmark them for quick access.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.outline)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: bookmarks.length,
              itemBuilder: (context, i) {
                final b = bookmarks[i];
                return _BookmarkCard(
                  bookmark: b,
                  onTap: () => context.push(
                    '/browser?path=${Uri.encodeComponent(b.path)}',
                  ),
                  onRemove: () {
                    ref.read(bookmarkServiceProvider).removeBookmark(b.path);
                    ref.invalidate(bookmarksProvider);
                  },
                );
              },
            ),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({
    required this.bookmark,
    required this.onTap,
    required this.onRemove,
  });

  final BookmarkedFolder bookmark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder, size: 48, color: cs.primary),
              const SizedBox(height: 8),
              Text(
                bookmark.displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
