import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/file_entry.dart';
import '../../providers/services_providers.dart';

class _GalleryImage {
  const _GalleryImage({required this.name, required this.streamUri});
  final String name;
  final String streamUri;
}

class _GalleryNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<_GalleryImage>, String> {
  @override
  Future<List<_GalleryImage>> build(String folderPath) async {
    final api = ref.read(apiServiceProvider);
    final listing = await api.getFolderListing(folderPath);
    if (listing == null) throw Exception('Could not load folder.');

    final images =
        listing.entries.where((e) => e.type == FileType.image).toList();
    final result = <_GalleryImage>[];
    for (final img in images) {
      final uri = await api.buildStreamUriWithToken(img.path);
      result.add(_GalleryImage(name: img.name, streamUri: uri));
    }
    return result;
  }
}

final _galleryProvider = AsyncNotifierProvider.autoDispose
    .family<_GalleryNotifier, List<_GalleryImage>, String>(_GalleryNotifier.new);

class ImageGalleryScreen extends ConsumerStatefulWidget {
  const ImageGalleryScreen(
      {super.key, required this.folderPath, required this.startIndex});
  final String folderPath;
  final int startIndex;

  @override
  ConsumerState<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends ConsumerState<ImageGalleryScreen> {
  late PageController _pageCtrl;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    _pageCtrl = PageController(initialPage: widget.startIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncImages = ref.watch(_galleryProvider(widget.folderPath));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: asyncImages.whenData((imgs) {
          if (imgs.isEmpty) return const Text('Gallery');
          final name = _currentIndex < imgs.length
              ? imgs[_currentIndex].name
              : '';
          return Text(name,
              style: const TextStyle(fontSize: 14, color: Colors.white70));
        }).valueOrNull,
      ),
      body: asyncImages.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (err, _) =>
            Center(child: Text('$err', style: const TextStyle(color: Colors.white))),
        data: (images) {
          if (images.isEmpty) {
            return const Center(
                child: Text('No images', style: TextStyle(color: Colors.white)));
          }
          return Stack(
            children: [
              PageView.builder(
                controller: _pageCtrl,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, i) {
                  return InteractiveViewer(
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: images[i].streamUri,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(color: Colors.white)),
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image,
                            color: Colors.white54, size: 64),
                      ),
                    ),
                  );
                },
              ),
              // Navigation arrows
              if (_currentIndex > 0)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _NavButton(
                      icon: Icons.chevron_left,
                      onTap: () => _pageCtrl.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut),
                    ),
                  ),
                ),
              if (_currentIndex < images.length - 1)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _NavButton(
                      icon: Icons.chevron_right,
                      onTap: () => _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut),
                    ),
                  ),
                ),
              // Counter
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Text(
                  '${_currentIndex + 1} / ${images.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}
