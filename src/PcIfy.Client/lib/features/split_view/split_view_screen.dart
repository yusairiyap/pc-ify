import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/models/file_entry.dart';
import '../../providers/services_providers.dart';

// ─── Data ────────────────────────────────────────────────────────────────────

class _PaneItem {
  const _PaneItem({
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

// ─── Public entry type passed from the browser ───────────────────────────────

class SplitViewEntry {
  const SplitViewEntry({
    required this.name,
    required this.filePath,
    required this.isVideo,
    this.streamUri,
    this.thumbnailUri,
  });
  final String name;
  final String filePath;
  final bool isVideo;
  final String? streamUri;
  final String? thumbnailUri;
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class SplitViewScreen extends ConsumerStatefulWidget {
  const SplitViewScreen({
    super.key,
    required this.folderPath,
    required this.selectedItems,
  });
  final String folderPath;
  final List<SplitViewEntry> selectedItems;

  @override
  ConsumerState<SplitViewScreen> createState() => _SplitViewScreenState();
}

class _SplitViewScreenState extends ConsumerState<SplitViewScreen> {
  List<_PaneItem> _paneItems = [];
  List<_PaneItem> _allMedia = [];
  bool _loaded = false;
  String? _error;

  // Flex weights for each pane (sum = 100)
  late List<double> _weights;

  // null = auto from MediaQuery; true = force horizontal; false = force vertical
  bool? _isHorizontalOverride;

  bool _appBarVisible = true;
  Timer? _appBarHideTimer;

  void _resetAppBarTimer() {
    _appBarHideTimer?.cancel();
    if (!_appBarVisible) setState(() => _appBarVisible = true);
    _appBarHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _appBarVisible = false);
    });
  }

  @override
  void initState() {
    super.initState();
    _weights = List.filled(widget.selectedItems.length, 100.0 / widget.selectedItems.length);
    _loadMedia();
    _resetAppBarTimer();
  }

  Future<void> _loadMedia() async {
    try {
      final api = ref.read(apiServiceProvider);
      final listing = await api.getFolderListing(widget.folderPath);
      if (listing == null) throw Exception('Could not load folder.');

      // Build all media items for carousel navigation in each pane
      final allMedia = <_PaneItem>[];
      for (final e in listing.entries) {
        if (e.type != FileType.image && e.type != FileType.video) continue;
        final uri = await api.buildStreamUriWithToken(e.path);
        final thumb = e.hasThumbnail ? await api.buildThumbnailUriWithToken(e.path) : null;
        allMedia.add(_PaneItem(
          name: e.name,
          streamUri: uri,
          isVideo: e.type == FileType.video,
          thumbnailUri: thumb,
        ));
      }

      // Map selected items to their index in the full media list
      final paneItems = <_PaneItem>[];
      for (final sel in widget.selectedItems) {
        final match = allMedia.where((m) => m.name == sel.name).firstOrNull;
        if (match != null) {
          paneItems.add(match);
        } else {
          // Fallback: use pre-built URI if available, otherwise fetch
          final uri = sel.streamUri ?? await api.buildStreamUriWithToken(sel.filePath);
          final thumb = sel.thumbnailUri ??
              (sel.filePath.isNotEmpty
                  ? await api.buildThumbnailUriWithToken(sel.filePath)
                  : null);
          paneItems.add(_PaneItem(
            name: sel.name,
            streamUri: uri,
            isVideo: sel.isVideo,
            thumbnailUri: thumb,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _allMedia = allMedia;
          _paneItems = paneItems;
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _appBarHideTimer?.cancel();
    super.dispose();
  }

  void _onDrag(int dividerIndex, double delta, double totalSize) {
    setState(() {
      const minWeight = 8.0; // ~80dp equivalent in flex units
      final totalWeight = _weights.reduce((a, b) => a + b);
      final deltaWeight = (delta / totalSize) * totalWeight;
      final left = _weights[dividerIndex] + deltaWeight;
      final right = _weights[dividerIndex + 1] - deltaWeight;
      if (left < minWeight || right < minWeight) return;
      _weights[dividerIndex] = left;
      _weights[dividerIndex + 1] = right;
    });
  }

  @override
  Widget build(BuildContext context) {
    final autoHorizontal = MediaQuery.sizeOf(context).shortestSide >= 600;
    final isHorizontal = _isHorizontalOverride ?? autoHorizontal;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: IgnorePointer(
          ignoring: !_appBarVisible,
          child: AnimatedOpacity(
            opacity: _appBarVisible ? 1.0 : 0.0,
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
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
              ),
              title: Text('${widget.selectedItems.length} items',
                  style: const TextStyle(fontSize: 14, color: Colors.white70)),
              actions: [
                IconButton(
                  tooltip: isHorizontal ? 'Stack vertically' : 'Split side by side',
                  icon: Icon(isHorizontal
                      ? Icons.view_stream_rounded
                      : Icons.view_column_rounded),
                  onPressed: () =>
                      setState(() => _isHorizontalOverride = !isHorizontal),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _resetAppBarTimer(),
        child: !_loaded
            ? Center(
                child: _error != null
                    ? Text(_error!, style: const TextStyle(color: Colors.white))
                    : const CircularProgressIndicator(color: Colors.white),
              )
            : _buildPanes(context, isHorizontal),
      ),
    );
  }

  Widget _buildPanes(BuildContext context, bool isHorizontal) {
    final count = _paneItems.length;

    final panes = <Widget>[
      for (int i = 0; i < count; i++)
        _SplitPane(
          key: ValueKey(i),
          startItem: _paneItems[i],
          allMedia: _allMedia,
          paneIndex: i,
        ),
    ];

    if (count == 1) return panes.first;

    // Build panes interleaved with draggable dividers
    return LayoutBuilder(builder: (context, constraints) {
      final totalSize = !isHorizontal ? constraints.maxHeight : constraints.maxWidth;
      final children = <Widget>[];

      for (int i = 0; i < count; i++) {
        children.add(Expanded(
          flex: (_weights[i] * 100).round(),
          child: panes[i],
        ));
        if (i < count - 1) {
          final divIdx = i;
          children.add(_Divider(
            isHorizontal: !isHorizontal,
            onDrag: (delta) => _onDrag(divIdx, delta, totalSize),
          ));
        }
      }

      return !isHorizontal
          ? Column(children: children)
          : Row(children: children);
    });
  }
}

// ─── Divider ─────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider({required this.isHorizontal, required this.onDrag});
  final bool isHorizontal;
  final void Function(double delta) onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: isHorizontal ? (d) => onDrag(d.delta.dy) : null,
      onHorizontalDragUpdate: isHorizontal ? null : (d) => onDrag(d.delta.dx),
      child: Container(
        width: isHorizontal ? double.infinity : 6,
        height: isHorizontal ? 6 : double.infinity,
        color: Colors.white24,
        child: Center(
          child: Container(
            width: isHorizontal ? 32 : 2,
            height: isHorizontal ? 2 : 32,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}

// ─── Single pane ─────────────────────────────────────────────────────────────

class _SplitPane extends ConsumerStatefulWidget {
  const _SplitPane({
    super.key,
    required this.startItem,
    required this.allMedia,
    required this.paneIndex,
  });
  final _PaneItem startItem;
  final List<_PaneItem> allMedia;
  final int paneIndex;

  @override
  ConsumerState<_SplitPane> createState() => _SplitPaneState();
}

class _SplitPaneState extends ConsumerState<_SplitPane>
    with TickerProviderStateMixin {
  late PageController _pageCtrl;
  late ScrollController _carouselCtrl;
  int _currentIndex = 0;

  static const _thumbSize = 48.0;
  static const _thumbMargin = 3.0;

  final _zoomedNotifier = ValueNotifier(false);
  bool _isVideoSeeking = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  DateTime? _controlsShownAt;
  Offset? _tapStart;
  bool _visibleAtTapStart = false;

  final _currentPlayerNotifier = ValueNotifier<Player?>(null);
  late final ValueNotifier<int> _activeIndexNotifier;
  final _tfControllers = <int, TransformationController>{};
  late final AnimationController _zoomAnimCtrl;
  Animation<Matrix4>? _zoomAnim;
  int? _zoomAnimIndex;
  Offset? _doubleTapPos;

  static const _hideDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    final startIdx = widget.allMedia.indexWhere(
        (m) => m.streamUri == widget.startItem.streamUri);
    _currentIndex = startIdx < 0 ? 0 : startIdx;
    _pageCtrl = PageController(initialPage: _currentIndex);
    _carouselCtrl = ScrollController();
    _activeIndexNotifier = ValueNotifier(_currentIndex);
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
    for (final c in _tfControllers.values) {
      c.dispose();
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
      _tapStart = null;
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    final wasTap = _tapStart != null;
    _tapStart = null;
    if (wasTap && _visibleAtTapStart) {
      final justShown = _controlsShownAt != null &&
          DateTime.now().difference(_controlsShownAt!).inMilliseconds < 400;
      if (!justShown) {
        _hideTimer?.cancel();
        setState(() => _controlsVisible = false);
        return;
      }
    }
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
    setState(() => _currentIndex = index);
    _activeIndexNotifier.value = index;
    for (final c in _tfControllers.values) {
      c.value = Matrix4.identity();
    }
    _resetHideTimer();
    // Scroll carousel to keep selected thumb visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_carouselCtrl.hasClients) return;
      const itemW = _thumbSize + _thumbMargin * 2;
      final target = index * itemW - (_carouselCtrl.position.viewportDimension / 2) + itemW / 2;
      _carouselCtrl.animateTo(
        target.clamp(0.0, _carouselCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleDoubleTap(int index) {
    final pos = _doubleTapPos;
    if (pos == null) return;
    final ctrl = _tfControllerFor(index);
    final isZoomed = ctrl.value.getMaxScaleOnAxis() > 1.01;
    final target = isZoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..translateByDouble(-pos.dx * 1.5, -pos.dy * 1.5, 0, 1)
          ..scaleByDouble(2.5, 2.5, 1, 1));
    _zoomAnim = Matrix4Tween(begin: ctrl.value, end: target)
        .animate(CurvedAnimation(parent: _zoomAnimCtrl, curve: Curves.easeOut));
    _zoomAnimIndex = index;
    _zoomAnimCtrl
      ..reset()
      ..forward();
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
          onHorizontalDragStart: (_) => setState(() => _isVideoSeeking = true),
          onHorizontalDragUpdate: (d) {
            if (dur == Duration.zero) return;
            final frac = (d.localPosition.dx / barWidth).clamp(0.0, 1.0);
            player.seek(Duration(milliseconds: (frac * dur.inMilliseconds).round()));
          },
          onHorizontalDragEnd: (_) => setState(() => _isVideoSeeking = false),
          onTapDown: (d) {
            if (dur == Duration.zero) return;
            final frac = (d.localPosition.dx / barWidth).clamp(0.0, 1.0);
            player.seek(Duration(milliseconds: (frac * dur.inMilliseconds).round()));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SizedBox(
              height: 36,
              child: Row(
                children: [
                  Text(_formatDuration(pos),
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: t,
                        minHeight: 4,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(_formatDuration(dur),
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _thumbContent(_PaneItem item) {
    if (item.thumbnailUri != null) {
      return CachedNetworkImage(
        imageUrl: item.thumbnailUri!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Icon(
      item.isVideo ? Icons.videocam : Icons.image,
      color: Colors.white54,
      size: 20,
    );
  }

  Widget _buildControls(List<_PaneItem> items) {
    final item = items[_currentIndex];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Video seek bar + play/pause
          if (item.isVideo)
            ValueListenableBuilder<Player?>(
              valueListenable: _currentPlayerNotifier,
              builder: (_, player, __) {
                if (player == null) return const SizedBox(height: 36);
                return Row(
                  children: [
                    StreamBuilder<bool>(
                      stream: player.stream.playing,
                      initialData: player.state.playing,
                      builder: (_, snap) => IconButton(
                        icon: Icon(
                          snap.data == true
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => snap.data == true
                            ? player.pause()
                            : player.play(),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (_, c) => _buildSeekBar(player, c.maxWidth - 60),
                      ),
                    ),
                  ],
                );
              },
            ),
          // Thumbnail carousel strip
          SizedBox(
            height: _thumbSize + _thumbMargin * 2 + 6,
            child: ListView.builder(
              controller: _carouselCtrl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final isSelected = i == _currentIndex;
                return GestureDetector(
                  onTap: () => _pageCtrl.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: _thumbMargin),
                    width: isSelected ? _thumbSize + 4 : _thumbSize,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _thumbContent(items[i]),
                          if (items[i].isVideo)
                            const Center(
                              child: Icon(Icons.play_arrow_rounded,
                                  color: Colors.white70, size: 14),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.allMedia.isEmpty ? [widget.startItem] : widget.allMedia;

    return ClipRect(
      child: Stack(
        children: [
          // PageView
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
                  return _PaneVideoPage(
                    key: ValueKey('pane${widget.paneIndex}_video_$i'),
                    streamUri: item.streamUri,
                    index: i,
                    activeIndexNotifier: _activeIndexNotifier,
                    playerNotifier: _currentPlayerNotifier,
                  );
                }
                return GestureDetector(
                  onDoubleTapDown: (d) => _doubleTapPos = d.localPosition,
                  onDoubleTap: () => _handleDoubleTap(i),
                  child: InteractiveViewer(
                    transformationController: _tfControllerFor(i),
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: item.streamUri,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(color: Colors.white)),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.broken_image, color: Colors.white54, size: 48),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Tap overlay
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            child: const SizedBox.expand(),
          ),
          // Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _buildControls(items),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pane video page ──────────────────────────────────────────────────────────

class _PaneVideoPage extends StatefulWidget {
  const _PaneVideoPage({
    super.key,
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
  State<_PaneVideoPage> createState() => _PaneVideoPageState();
}

class _PaneVideoPageState extends State<_PaneVideoPage> {
  late final Player _player;
  late final VideoController _controller;
  bool _ready = false;

  Offset? _doubleTapPos;
  bool _seekLeft = false;
  bool _seekRight = false;
  Timer? _seekFeedbackTimer;

  bool get _isActive => widget.activeIndexNotifier.value == widget.index;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    widget.activeIndexNotifier.addListener(_onActiveChanged);
    _initStream();
  }

  Future<void> _initStream() async {
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
      if (mounted) {
        setState(() {
          _seekLeft = false;
          _seekRight = false;
        });
      }
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
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      return Stack(
        children: [
          Video(controller: _controller, controls: NoVideoControls),
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
          if (_seekLeft)
            Positioned(
              left: 0, top: 0, bottom: 0,
              width: w / 2,
              child: const _SeekIndicator(left: true),
            ),
          if (_seekRight)
            Positioned(
              right: 0, top: 0, bottom: 0,
              width: w / 2,
              child: const _SeekIndicator(left: false),
            ),
        ],
      );
    });
  }
}

class _SeekIndicator extends StatelessWidget {
  const _SeekIndicator({required this.left});
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      child: Center(
        child: Icon(
          left ? Icons.fast_rewind_rounded : Icons.fast_forward_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}
