import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/models/file_entry.dart';
import '../../providers/services_providers.dart';
import '../../services/api_service.dart' show ApiService;

// --- Data model ---

class _GalleryItem {
  const _GalleryItem({
    required this.name,
    required this.streamUri,
    required this.isVideo,
    this.thumbnailUri,
  });
  final String name;
  final String streamUri;
  final bool isVideo;
  final String? thumbnailUri;
}

// --- Provider ---

class _GalleryNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<_GalleryItem>, String> {
  @override
  Future<List<_GalleryItem>> build(String folderPath) async {
    final api = ref.read(apiServiceProvider);
    final listing = await api.getFolderListing(folderPath);
    if (listing == null) throw Exception('Could not load folder.');

    final media = listing.entries
        .where((e) => e.type == FileType.image || e.type == FileType.video)
        .toList();

    final result = <_GalleryItem>[];
    for (final item in media) {
      final uri = await api.buildStreamUriWithToken(item.path);
      final thumbUri = item.hasThumbnail
          ? await api.buildThumbnailUriWithToken(item.path)
          : null;
      result.add(_GalleryItem(
        name: item.name,
        streamUri: uri,
        isVideo: item.type == FileType.video,
        thumbnailUri: thumbUri,
      ));
    }
    return result;
  }
}

final _galleryProvider = AsyncNotifierProvider.autoDispose
    .family<_GalleryNotifier, List<_GalleryItem>, String>(_GalleryNotifier.new);

// --- Screen ---

class ImageGalleryScreen extends ConsumerStatefulWidget {
  const ImageGalleryScreen({
    super.key,
    required this.folderPath,
    required this.startIndex,
    this.initialPositionMs,
  });
  final String folderPath;
  final int startIndex;
  final int? initialPositionMs;

  @override
  ConsumerState<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends ConsumerState<ImageGalleryScreen>
    with TickerProviderStateMixin {
  late final PageController _pageCtrl;
  late final ScrollController _carouselCtrl;
  int _currentIndex = 0;

  // Disables PageView swipe when image is zoomed or video seek bar is being dragged
  final _zoomedNotifier = ValueNotifier(false);
  bool _isVideoSeeking = false;

  // Active video player — set by gallery video pages
  final _currentPlayerNotifier = ValueNotifier<Player?>(null);

  // Shared mute state across all video pages
  final _muteNotifier = ValueNotifier<bool>(false);

  // Signals which gallery index is currently visible (video pages listen to this)
  late final ValueNotifier<int> _activeIndexNotifier;

  // TransformationControllers keyed by page index so we can reset them on page change
  final _tfControllers = <int, TransformationController>{};

  // Smooth double-tap zoom
  late final AnimationController _zoomAnimCtrl;
  Animation<Matrix4>? _zoomAnim;
  int? _zoomAnimIndex;
  Offset? _doubleTapPos;

  bool _showTimelineStrip = false;

  static const _thumbSize = 60.0;
  static const _thumbMargin = 4.0;
  static const _hideDelay = Duration(seconds: 3);

  // Controls (AppBar, nav buttons, carousel) visibility
  bool _controlsVisible = true;
  Timer? _hideTimer;
  DateTime? _controlsShownAt; // when controls last became visible

  // Tap tracking for tap-to-toggle (distinguishes tap from swipe/double-tap)
  Offset? _tapStart;
  bool _visibleAtTapStart = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    _pageCtrl = PageController(initialPage: widget.startIndex);
    _carouselCtrl = ScrollController();
    _activeIndexNotifier = ValueNotifier(widget.startIndex);
    _zoomAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    )..addListener(_onZoomTick);
    _resetHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pageCtrl.dispose();
    _carouselCtrl.dispose();
    _zoomedNotifier.dispose();
    _currentPlayerNotifier.dispose();
    _activeIndexNotifier.dispose();
    _muteNotifier.dispose();
    _zoomAnimCtrl.dispose();
    for (final ctrl in _tfControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      _controlsShownAt = DateTime.now();
    }
    _scheduleHide();
  }

  // --- Tap-to-toggle logic ---
  // onPointerDown / onPointerMove / onPointerUp are used by the Listener overlay.
  // A "tap" = pointer up with minimal movement.
  // Tap when controls visible  → hide immediately, UNLESS controls were just shown
  //   within 400 ms (prevents double-tap-to-zoom from also closing the controls).
  // Tap when controls hidden   → already shown on pointer-down; schedule auto-hide.
  // Swipe / drag               → _tapStart cleared by move; just schedule auto-hide.

  void _onPointerDown(PointerDownEvent e) {
    _tapStart = e.localPosition;
    _visibleAtTapStart = _controlsVisible;
    _hideTimer?.cancel();
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      _controlsShownAt = DateTime.now();
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_tapStart != null && (e.localPosition - _tapStart!).distance > 12) {
      _tapStart = null; // too much movement — treat as drag, not tap
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    final wasTap = _tapStart != null;
    _tapStart = null;

    if (wasTap && _visibleAtTapStart) {
      final justShown = _controlsShownAt != null &&
          DateTime.now().difference(_controlsShownAt!).inMilliseconds < 400;
      if (!justShown) {
        // Single tap while controls were already visible → hide now
        _hideTimer?.cancel();
        setState(() => _controlsVisible = false);
        return;
      }
    }

    // Drag ended, tap-to-show, or double-tap second touch → schedule auto-hide
    _scheduleHide();
  }

  TransformationController _tfControllerFor(int index) {
    return _tfControllers.putIfAbsent(index, () {
      final ctrl = TransformationController();
      ctrl.addListener(() {
        final isZoomed = ctrl.value.getMaxScaleOnAxis() > 1.01;
        if (isZoomed != _zoomedNotifier.value) {
          _zoomedNotifier.value = isZoomed;
        }
      });
      return ctrl;
    });
  }

  void _onZoomTick() {
    final anim = _zoomAnim;
    final idx = _zoomAnimIndex;
    if (anim == null || idx == null) return;
    _tfControllers[idx]?.value = anim.value;
  }

  void _onPageChanged(int index) {
    _zoomAnimCtrl.stop();
    _tfControllers[_currentIndex]?.value = Matrix4.identity();
    _zoomedNotifier.value = false;
    setState(() => _currentIndex = index);
    _activeIndexNotifier.value = index;
    _resetHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_carouselCtrl.hasClients) return;
      const itemWidth = _thumbSize + _thumbMargin * 2;
      final viewportWidth = _carouselCtrl.position.viewportDimension;
      final target = (index * itemWidth) - viewportWidth / 2 + itemWidth / 2;
      _carouselCtrl.animateTo(
        target.clamp(0.0, _carouselCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _handleImageDoubleTap(int index) {
    final pos = _doubleTapPos;
    if (pos == null) return;
    final ctrl = _tfControllerFor(index);
    final begin = Matrix4.copy(ctrl.value);
    final isZoomed = begin.getMaxScaleOnAxis() > 1.01;

    final Matrix4 end;
    if (isZoomed) {
      end = Matrix4.identity();
    } else {
      const scale = 2.5;
      end = Matrix4.translationValues(pos.dx, pos.dy, 0)
          .multiplied(Matrix4.diagonal3Values(scale, scale, 1))
          .multiplied(Matrix4.translationValues(-pos.dx, -pos.dy, 0));
    }

    _zoomAnimCtrl.stop();
    _zoomAnimIndex = index;
    _zoomAnim = Matrix4Tween(begin: begin, end: end).animate(
        CurvedAnimation(parent: _zoomAnimCtrl, curve: Curves.easeOutCubic));
    _zoomAnimCtrl.forward(from: 0);
  }

  Widget _thumbContent(_GalleryItem item) {
    if (item.thumbnailUri != null) {
      return CachedNetworkImage(
        imageUrl: item.thumbnailUri!,
        fit: BoxFit.cover,
        memCacheWidth: 120,
        placeholder: (_, __) => _thumbPlaceholder(item.isVideo),
        errorWidget: (_, __, ___) => _thumbPlaceholder(item.isVideo),
      );
    }
    if (!item.isVideo) {
      return CachedNetworkImage(
        imageUrl: item.streamUri,
        fit: BoxFit.cover,
        memCacheWidth: 120,
        placeholder: (_, __) => _thumbPlaceholder(false),
        errorWidget: (_, __, ___) => _thumbPlaceholder(false),
      );
    }
    return _thumbPlaceholder(true);
  }

  Widget _thumbPlaceholder(bool isVideo) {
    return Container(
      color: Colors.grey[850],
      child: Icon(
        isVideo ? Icons.play_circle_outline : Icons.image_outlined,
        color: Colors.white38,
        size: 22,
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Widget _buildSeekBar(Player player, double barWidth) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (_, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = player.state.duration;
        final t = dur.inMilliseconds > 0
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) =>
              setState(() => _isVideoSeeking = true),
          onHorizontalDragUpdate: (d) {
            if (dur == Duration.zero) return;
            final frac = (d.localPosition.dx / barWidth).clamp(0.0, 1.0);
            player.seek(Duration(
                milliseconds: (frac * dur.inMilliseconds).round()));
          },
          onHorizontalDragEnd: (_) =>
              setState(() => _isVideoSeeking = false),
          onTapDown: (d) {
            if (dur == Duration.zero) return;
            final frac = (d.localPosition.dx / barWidth).clamp(0.0, 1.0);
            player.seek(Duration(
                milliseconds: (frac * dur.inMilliseconds).round()));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Text(_formatDuration(pos),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: t,
                        minHeight: 6,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_formatDuration(dur),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Fit mode helpers ---

  static String _fitLabel(BoxFit fit) => switch (fit) {
        BoxFit.cover => 'Crop to Fit',
        BoxFit.fill => 'Stretch',
        _ => 'Fit to Screen',
      };

  static IconData _fitIcon(BoxFit fit) => switch (fit) {
        BoxFit.cover => Icons.crop_rounded,
        BoxFit.fill => Icons.fit_screen_rounded,
        _ => Icons.aspect_ratio_rounded,
      };

  void _cycleFit(WidgetRef ref) {
    final current = ref.read(videoFitProvider);
    final next = switch (current) {
      BoxFit.contain => BoxFit.cover,
      BoxFit.cover => BoxFit.fill,
      _ => BoxFit.contain,
    };
    ref.read(videoFitProvider.notifier).state = next;
    ref.read(sharedPrefsProvider).setString(
        'video_fit_mode',
        switch (next) {
          BoxFit.cover => 'cover',
          BoxFit.fill => 'fill',
          _ => 'contain',
        });
  }

  void _toggleRepeat(WidgetRef ref, Player player) {
    final next = !ref.read(videoRepeatProvider);
    ref.read(videoRepeatProvider.notifier).state = next;
    ref.read(sharedPrefsProvider).setBool('video_auto_repeat', next);
    player.setPlaylistMode(next ? PlaylistMode.loop : PlaylistMode.none);
  }

  Widget _buildBottomOverlay(List<_GalleryItem> items) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.65),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Video seek bar + controls
          if (items[_currentIndex].isVideo)
            ValueListenableBuilder<Player?>(
              valueListenable: _currentPlayerNotifier,
              builder: (context, player, _) {
                if (player == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: 0,
                        backgroundColor: Color(0x40FFFFFF),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0x50FFFFFF)),
                      ),
                    ),
                  );
                }
                // Timeline strip — slides up/down with AnimatedSize
                final durationMs =
                    player.state.duration.inMilliseconds;
                final api = ref.read(apiServiceProvider);
                final quality = ref
                        .read(sharedPrefsProvider)
                        .getInt('thumbnail_quality') ??
                    50;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Collapsible timeline strip
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: _showTimelineStrip && durationMs > 0
                          ? Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(8, 8, 8, 0),
                              child: _GalleryTimelineStrip(
                                player: player,
                                durationMs: durationMs,
                                filePath: items[_currentIndex].streamUri,
                                api: api,
                                quality: quality,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Row(
                      children: [
                    // Play/pause
                    StreamBuilder<bool>(
                      stream: player.stream.playing,
                      initialData: player.state.playing,
                      builder: (_, snap) => IconButton(
                        icon: Icon(
                          snap.data == true
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          if (player.state.playing) {
                            player.pause();
                          } else {
                            player.play();
                          }
                        },
                      ),
                    ),
                    // Seek bar
                    Expanded(
                      child: LayoutBuilder(
                        builder: (_, constraints) =>
                            _buildSeekBar(player, constraints.maxWidth - 80),
                      ),
                    ),
                    // Timeline strip toggle
                    IconButton(
                      tooltip: _showTimelineStrip
                          ? 'Hide timeline'
                          : 'Show timeline',
                      icon: Icon(
                        Icons.view_timeline_outlined,
                        color: _showTimelineStrip
                            ? Colors.white
                            : Colors.white38,
                        size: 20,
                      ),
                      onPressed: () => setState(
                          () => _showTimelineStrip = !_showTimelineStrip),
                    ),
                    // Fit mode cycle
                    Consumer(builder: (context, ref, _) {
                      final fit = ref.watch(videoFitProvider);
                      return IconButton(
                        tooltip: _fitLabel(fit),
                        icon: Icon(_fitIcon(fit), color: Colors.white, size: 20),
                        onPressed: () => _cycleFit(ref),
                      );
                    }),
                    // Repeat toggle
                    Consumer(builder: (context, ref, _) {
                      final repeat = ref.watch(videoRepeatProvider);
                      return IconButton(
                        tooltip: repeat ? 'Repeat on' : 'Repeat off',
                        icon: Icon(
                          Icons.repeat_one_rounded,
                          color: repeat ? Colors.white : Colors.white38,
                          size: 20,
                        ),
                        onPressed: () => _toggleRepeat(ref, player),
                      );
                    }),
                    // Mute toggle
                    ValueListenableBuilder<bool>(
                      valueListenable: _muteNotifier,
                      builder: (_, isMuted, __) => IconButton(
                        tooltip: isMuted ? 'Unmute' : 'Mute',
                        icon: Icon(
                          isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          final next = !_muteNotifier.value;
                          _muteNotifier.value = next;
                          player.setVolume(next ? 0 : 100);
                        },
                      ),
                    ),
                  ],
                ),  // Row
                  ],
                ); // Column
              },
            ),
          // Thumbnail carousel
          SizedBox(
            height: _thumbSize + _thumbMargin * 2 + 8,
            child: ListView.builder(
              controller: _carouselCtrl,
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final isSelected = i == _currentIndex;
                return GestureDetector(
                  onTap: () => _pageCtrl.animateToPage(i,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(
                        horizontal: _thumbMargin),
                    width: isSelected ? _thumbSize + 4 : _thumbSize,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _thumbContent(items[i]),
                          if (items[i].isVideo)
                            const Center(
                              child: Icon(Icons.play_arrow_rounded,
                                  color: Colors.white70, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
              height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(_galleryProvider(widget.folderPath));
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: IgnorePointer(
          ignoring: !_controlsVisible,
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Colors.transparent],
                  ),
                ),
              ),
              title: asyncItems.whenData((items) {
                if (items.isEmpty) return const Text('Gallery');
                final name = _currentIndex < items.length
                    ? items[_currentIndex].name
                    : '';
                return Text(name,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.white70));
              }).valueOrNull,
            ),
          ),
        ),
      ),
      body: asyncItems.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white)),
        error: (err, _) => Center(
            child:
                Text('$err', style: const TextStyle(color: Colors.white))),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
                child: Text('No media',
                    style: TextStyle(color: Colors.white)));
          }
          // Carousel height used to vertically center nav buttons
          const carouselH = _thumbSize + _thumbMargin * 2 + 8;
          final seekBarH =
              items[_currentIndex].isVideo ? 52.0 : 0.0;
          final bottomOverlayH = carouselH +
              seekBarH +
              MediaQuery.of(context).padding.bottom;

          return Stack(
            children: [
              // Full-screen PageView
              ValueListenableBuilder<bool>(
                valueListenable: _zoomedNotifier,
                builder: (_, isZoomed, __) => PageView.builder(
                  controller: _pageCtrl,
                  physics: (isZoomed || _isVideoSeeking)
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: items.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    if (item.isVideo) {
                      return _GalleryVideoPage(
                        streamUri: item.streamUri,
                        index: i,
                        activeIndexNotifier: _activeIndexNotifier,
                        playerNotifier: _currentPlayerNotifier,
                        zoomedNotifier: _zoomedNotifier,
                        muteNotifier: _muteNotifier,
                        initialPositionMs: i == widget.startIndex
                            ? widget.initialPositionMs
                            : null,
                      );
                    }
                    return GestureDetector(
                      onDoubleTapDown: (d) =>
                          _doubleTapPos = d.localPosition,
                      onDoubleTap: () => _handleImageDoubleTap(i),
                      child: InteractiveViewer(
                        transformationController: _tfControllerFor(i),
                        minScale: 1.0,
                        maxScale: 5.0,
                        child: Center(
                          child: CachedNetworkImage(
                            imageUrl: item.streamUri,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white)),
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.broken_image,
                                color: Colors.white54,
                                size: 64),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Transparent interaction detector — handles tap-to-toggle and
              // resets the auto-hide timer, without entering the gesture arena
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                child: const SizedBox.expand(),
              ),
              // Nav buttons — vertically centered in the visible area
              if (_currentIndex > 0)
                Positioned(
                  left: 8,
                  top: topPad + kToolbarHeight,
                  bottom: bottomOverlayH,
                  child: Center(
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: AnimatedOpacity(
                        opacity: _controlsVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: _NavButton(
                          icon: Icons.chevron_left,
                          onTap: () => _pageCtrl.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_currentIndex < items.length - 1)
                Positioned(
                  right: 8,
                  top: topPad + kToolbarHeight,
                  bottom: bottomOverlayH,
                  child: Center(
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: AnimatedOpacity(
                        opacity: _controlsVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: _NavButton(
                          icon: Icons.chevron_right,
                          onTap: () => _pageCtrl.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut),
                        ),
                      ),
                    ),
                  ),
                ),
              // Bottom overlay: seek bar + carousel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: _buildBottomOverlay(items),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- Gallery video page ---

class _GalleryVideoPage extends ConsumerStatefulWidget {
  const _GalleryVideoPage({
    required this.streamUri,
    required this.index,
    required this.activeIndexNotifier,
    required this.playerNotifier,
    required this.zoomedNotifier,
    required this.muteNotifier,
    this.initialPositionMs,
  });
  final String streamUri;
  final int index;
  final ValueNotifier<int> activeIndexNotifier;
  final ValueNotifier<Player?> playerNotifier;
  final ValueNotifier<bool> zoomedNotifier;
  final ValueNotifier<bool> muteNotifier;
  final int? initialPositionMs;

  @override
  ConsumerState<_GalleryVideoPage> createState() => _GalleryVideoPageState();
}

class _GalleryVideoPageState extends ConsumerState<_GalleryVideoPage> {
  late final Player _player;
  late final VideoController _controller;
  bool _ready = false;

  // Pinch-zoom / pan state (managed via Listener to bypass gesture arena)
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  final Map<int, Offset> _activePointers = {};
  double? _pinchStartDist;
  double? _pinchStartScale;

  // Double-tap seek feedback
  Offset? _doubleTapPos;
  bool _seekLeft = false;
  bool _seekRight = false;
  Timer? _seekFeedbackTimer;

  bool get _isActive =>
      widget.activeIndexNotifier.value == widget.index;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    widget.activeIndexNotifier.addListener(_onActiveChanged);
    widget.muteNotifier.addListener(_onMuteChanged);
    _initStream();
  }

  void _onMuteChanged() {
    _player.setVolume(widget.muteNotifier.value ? 0 : 100);
  }

  Future<void> _initStream() async {
    final repeat = ref.read(videoRepeatProvider);
    await _player.setPlaylistMode(repeat ? PlaylistMode.loop : PlaylistMode.none);
    await _player.open(Media(widget.streamUri), play: false);
    final pos = widget.initialPositionMs;
    if (pos != null && pos > 0) {
      await _player.seek(Duration(milliseconds: pos));
    }
    _ready = true;
    if (_isActive) {
      widget.playerNotifier.value = _player;
      _player.setVolume(widget.muteNotifier.value ? 0 : 100);
      await _player.play();
    }
  }

  void _onActiveChanged() {
    if (!_ready) return;
    if (_isActive) {
      widget.playerNotifier.value = _player;
      _player.setVolume(widget.muteNotifier.value ? 0 : 100);
      // Reset zoom/pan when page becomes active
      _resetZoom();
      _player.play();
    } else {
      if (widget.playerNotifier.value == _player) {
        widget.playerNotifier.value = null;
      }
      _resetZoom();
      _player.pause();
    }
  }

  void _resetZoom() {
    if (_scale != 1.0 || _offset != Offset.zero) {
      setState(() {
        _scale = 1.0;
        _offset = Offset.zero;
      });
    }
    _activePointers.clear();
    _pinchStartDist = null;
    _pinchStartScale = null;
    if (_isActive) widget.zoomedNotifier.value = false;
  }

  void _handlePointerDown(PointerDownEvent e) {
    _activePointers[e.pointer] = e.localPosition;
    if (_activePointers.length == 2) {
      final pts = _activePointers.values.toList();
      _pinchStartDist = (pts[0] - pts[1]).distance;
      _pinchStartScale = _scale;
    }
  }

  void _handlePointerMove(PointerMoveEvent e) {
    final prev = _activePointers[e.pointer];
    _activePointers[e.pointer] = e.localPosition;

    if (_activePointers.length >= 2 &&
        _pinchStartDist != null &&
        _pinchStartDist! > 0) {
      final pts = _activePointers.values.toList();
      final dist = (pts[0] - pts[1]).distance;
      final newScale =
          (_pinchStartScale! * dist / _pinchStartDist!).clamp(1.0, 5.0);
      setState(() => _scale = newScale);
      if (_isActive) widget.zoomedNotifier.value = newScale > 1.01;
    } else if (_activePointers.length == 1 &&
        _scale > 1.01 &&
        prev != null) {
      // Single-finger pan when zoomed in
      final delta = e.localPosition - prev;
      setState(() => _offset = _offset + delta);
    }
  }

  void _handlePointerEnd(int pointer) {
    _activePointers.remove(pointer);
    if (_activePointers.length < 2) {
      _pinchStartDist = null;
      _pinchStartScale = null;
    }
    if (_scale <= 1.01) {
      setState(() {
        _scale = 1.0;
        _offset = Offset.zero;
      });
      if (_isActive) widget.zoomedNotifier.value = false;
    }
  }

  void _doubleTapSeek(bool left) {
    // Ignore if a multi-finger gesture is in progress
    if (_activePointers.length > 1) return;
    final dur = _player.state.duration;
    if (dur == Duration.zero) return;
    const delta = Duration(seconds: 10);
    final pos = _player.state.position;
    final newPos = left
        ? (pos - delta).isNegative ? Duration.zero : pos - delta
        : pos + delta > dur ? dur : pos + delta;
    _player.seek(newPos);
    _seekFeedbackTimer?.cancel();
    setState(() {
      _seekLeft = left;
      _seekRight = !left;
    });
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() { _seekLeft = false; _seekRight = false; });
    });
  }

  @override
  void dispose() {
    _seekFeedbackTimer?.cancel();
    widget.activeIndexNotifier.removeListener(_onActiveChanged);
    widget.muteNotifier.removeListener(_onMuteChanged);
    if (widget.playerNotifier.value == _player) {
      widget.playerNotifier.value = null;
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final fit = ref.watch(videoFitProvider);
    return Stack(
      children: [
        // Apply pinch-zoom and pan via Transform (avoids InteractiveViewer/gesture
        // arena conflicts with the platform Texture used by media_kit on Android)
        Transform.translate(
          offset: _offset,
          child: Transform.scale(
            scale: _scale,
            child: Video(
                controller: _controller, controls: NoVideoControls, fit: fit),
          ),
        ),
        // Raw pointer tracking for pinch-zoom and pan — Listener fires
        // unconditionally without entering the gesture arena
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: (e) => _handlePointerEnd(e.pointer),
          onPointerCancel: (e) => _handlePointerEnd(e.pointer),
          child: const SizedBox.expand(),
        ),
        // Double-tap left/right to seek ±10 s
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onDoubleTapDown: (d) => _doubleTapPos = d.localPosition,
          onDoubleTap: () {
            final pos = _doubleTapPos;
            if (pos == null) return;
            _doubleTapSeek(pos.dx < w / 2);
          },
          child: const SizedBox.expand(),
        ),
        // Seek feedback overlays
        if (_seekLeft)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: w / 2,
            child: const _SeekFeedback(left: true),
          ),
        if (_seekRight)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: w / 2,
            child: const _SeekFeedback(left: false),
          ),
      ],
    );
  }
}

// --- Seek feedback overlay ---

class _SeekFeedback extends StatelessWidget {
  const _SeekFeedback({required this.left});
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              left ? Icons.fast_rewind_rounded : Icons.fast_forward_rounded,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: 4),
            Text(
              left ? '- 10s' : '+ 10s',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Nav button ---

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

// ─── Gallery timeline strip ───────────────────────────────────────────────────

/// Thin adapter: derives thumbnail URIs from [filePath] (the stream URI) by
/// swapping the /stream/ segment for /thumbnails/ and appending quality + t=.
/// When server path is not known (stream URI only), falls back to
/// VideoTimelineStrip with directly built URIs via api.
class _GalleryTimelineStrip extends StatefulWidget {
  const _GalleryTimelineStrip({
    required this.player,
    required this.durationMs,
    required this.filePath,
    required this.api,
    required this.quality,
  });

  final Player player;
  final int durationMs;
  final String filePath; // stream URI — used only as identifier for the item
  final ApiService api;
  final int quality;

  @override
  State<_GalleryTimelineStrip> createState() => _GalleryTimelineStripState();
}

class _GalleryTimelineStripState extends State<_GalleryTimelineStrip> {
  static const _fracs = [0.15, 0.30, 0.45, 0.60, 0.75];
  List<String?>? _uris;

  @override
  void initState() {
    super.initState();
    _buildUris();
  }

  @override
  void didUpdateWidget(_GalleryTimelineStrip old) {
    super.didUpdateWidget(old);
    if (old.filePath != widget.filePath || old.durationMs != widget.durationMs) {
      setState(() => _uris = null);
      _buildUris();
    }
  }

  /// Extracts the server path from the stream URI by reversing the encoding
  /// applied by ApiService.buildStreamUriWithToken().
  String? _serverPathFromStreamUri(String streamUri) {
    try {
      final uri = Uri.parse(streamUri);
      // Path looks like /api/files/stream/<encodedServerPath>
      const prefix = '/api/files/stream/';
      if (uri.path.startsWith(prefix)) {
        return Uri.decodeComponent(uri.path.substring(prefix.length));
      }
    } catch (_) {}
    return null;
  }

  Future<void> _buildUris() async {
    final serverPath = _serverPathFromStreamUri(widget.filePath);
    if (serverPath == null) return;
    final uris = <String?>[];
    for (final frac in _fracs) {
      final posMs = (widget.durationMs * frac).round();
      final atSec = posMs / 1000.0;
      final uri = await widget.api.buildThumbnailUriWithToken(
        serverPath,
        quality: widget.quality,
        atSeconds: atSec,
      );
      uris.add(uri);
    }
    if (mounted) setState(() => _uris = uris);
  }

  String _ts(int posMs) {
    final d = Duration(milliseconds: posMs);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Row(
        children: List.generate(_fracs.length, (i) {
          final posMs = (widget.durationMs * _fracs[i]).round();
          final uri = _uris?[i];
          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  widget.player.seek(Duration(milliseconds: posMs)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: _uris == null
                            ? Container(
                                color: Colors.white12,
                              )
                            : uri != null
                                ? CachedNetworkImage(
                                    imageUrl: uri,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (_, __) => Container(
                                        color: Colors.white12),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.white12,
                                      child: const Icon(
                                          Icons.videocam_off_outlined,
                                          color: Colors.white38,
                                          size: 18),
                                    ),
                                  )
                                : Container(color: Colors.white12),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _ts(posMs),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
