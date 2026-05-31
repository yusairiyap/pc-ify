import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/file_entry.dart';
import '../../core/models/folder_listing.dart';
import '../../core/utils/grid_density_helper.dart';
import '../../providers/services_providers.dart';

class _PickerState {
  const _PickerState({required this.listing, required this.thumbnails});
  final FolderListing listing;
  final Map<String, String> thumbnails;
}

class _PickerNotifier
    extends AutoDisposeFamilyAsyncNotifier<_PickerState, String> {
  @override
  Future<_PickerState> build(String startPath) async => _load(startPath);

  Future<_PickerState> _load(String path) async {
    final api = ref.read(apiServiceProvider);

    FolderListing listing;
    if (path.isEmpty) {
      final roots = await api.getRoots();
      if (roots == null || roots.isEmpty) throw Exception('No source directories configured on server.');
      if (roots.length == 1) {
        final l = await api.getFolderListing(roots.first.path);
        if (l == null) throw Exception('Could not load folder.');
        listing = l;
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

    final filtered = listing.entries
        .where((e) =>
            e.type == FileType.folder ||
            e.type == FileType.image ||
            e.type == FileType.video)
        .toList()
      ..sort((a, b) {
        if (a.type == b.type) return a.name.compareTo(b.name);
        if (a.type == FileType.folder) return -1;
        if (b.type == FileType.folder) return 1;
        return 0;
      });

    final thumbs = <String, String>{};
    for (final e in filtered) {
      if (e.hasThumbnail) {
        thumbs[e.path] = await api.buildThumbnailUriWithToken(e.path);
      }
    }

    return _PickerState(
      listing: FolderListing(
          path: listing.path,
          parentPath: listing.parentPath,
          displayName: listing.displayName,
          entries: filtered),
      thumbnails: thumbs,
    );
  }

  Future<void> navigate(String path) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(path));
  }
}

final _pickerProvider = AsyncNotifierProvider.autoDispose
    .family<_PickerNotifier, _PickerState, String>(_PickerNotifier.new);

class ImagePickerScreen extends ConsumerWidget {
  const ImagePickerScreen({super.key, required this.startPath});
  final String startPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(_pickerProvider(startPath));
    final notifier = ref.read(_pickerProvider(startPath).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Background'),
        leading: asyncState.valueOrNull?.listing.parentPath != null
            ? IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: () => notifier.navigate(
                    asyncState.valueOrNull!.listing.parentPath!),
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => context.pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('$err')),
        data: (s) => Column(
          children: [
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 8),
                  Text('Tap an image or video to use it as background',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final density = GridDensityHelper.fromString(
                    ref.read(sharedPrefsProvider).getString('grid_density') ?? 'normal',
                  );
                  final cols = GridDensityHelper.getColumnCount(constraints.maxWidth, density);
                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: s.listing.entries.length,
                    itemBuilder: (context, i) {
                      final entry = s.listing.entries[i];
                      final thumbUri = s.thumbnails[entry.path];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            if (entry.type == FileType.folder) {
                              notifier.navigate(entry.path);
                            } else {
                              context.pop(entry.path);
                            }
                          },
                          child: Column(
                            children: [
                              Expanded(
                                child: thumbUri != null
                                    ? CachedNetworkImage(
                                        imageUrl: thumbUri,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      )
                                    : Center(
                                        child: Icon(
                                          entry.type == FileType.folder
                                              ? Icons.folder
                                              : entry.type == FileType.video
                                                  ? Icons.videocam_outlined
                                                  : Icons.image_outlined,
                                          size: 40,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 4),
                                child: Text(
                                  entry.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
