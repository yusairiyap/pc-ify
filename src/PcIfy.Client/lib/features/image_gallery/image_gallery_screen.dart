import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/models/file_entry.dart';
import '../../providers/services_providers.dart';

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
  const ImageGalleryScreen(
      {super.key, required this.folderPath, required this.startIndex});
  final String folderPath;
  final int startIndex;

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

  // Signals which gallery index is currently visible (video pages listen to this)
  late final ValueNotifier<int> _activeIndexNotifier;

  // TransformationControllers keyed by page index so we can reset them on page change
  final _tfControllers = <int, TransformationController>{};

  // Smooth double-tap zoom
  late final AnimationController _zoomAnimCtrl;
  Animation<Matrix4>? _zoomAnim;
  int? _zoomAnimIndex;
  Offset? _doubleTapPos;

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
          // Video seek bar
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
                return Row(
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
                  ],
                );
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
  });
  final String streamUri;
  final int index;
  final ValueNotifier<int> activeIndexNotifier;
  final ValueNotifier<Player?> playerNotifier;

  @override
  ConsumerState<_GalleryVideoPage> createState() => _GalleryVideoPageState();
}

class _GalleryVideoPageState extends ConsumerState<_GalleryVideoPage> {
  late final Player _player;
  late final VideoController _controller;
  bool _ready = false;

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
    _initStream();
  }

  Future<void> _initStream() async {
    final repeat = ref.read(videoRepeatProvider);
    await _player.setPlaylistMode(repeat ? PlaylistMode.loop : PlaylistMode.none);
    await _player.open(Media(widget.streamUri), play: false);
    _ready = true;
    if (_isActive) {
      widget.playerNotifier.value = _player;
      await _player.play();
    }
  }

  void _onActiveChanged() {
    if (!_ready) return;
    if (_isActive) {
      widget.playerNotifier.value = _player;
      _player.play();
    } else {
      if (widget.playerNotifier.value == _player) {
        widget.playerNotifier.value = null;
      }
      _player.pause();
    }
  }

  void _doubleTapSeek(bool left) {
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
        Video(controller: _controller, controls: NoVideoControls, fit: fit),
        // Double-tap left/right to seek
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
