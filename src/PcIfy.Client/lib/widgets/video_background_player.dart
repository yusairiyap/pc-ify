import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/models/folder_prefs.dart';

class VideoBackgroundPlayer extends StatefulWidget {
  const VideoBackgroundPlayer(
      {super.key, required this.videoUri, required this.prefs});
  final String videoUri;
  final FolderPrefs prefs;

  @override
  State<VideoBackgroundPlayer> createState() => _VideoBackgroundPlayerState();
}

class _VideoBackgroundPlayerState extends State<VideoBackgroundPlayer>
    with SingleTickerProviderStateMixin {
  late Player _player;
  late VideoController _controller;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _initPlayer();
  }

  void _initPlayer() {
    _player = Player();
    _controller = VideoController(_player);
    _player.setVolume(0);
    _player.setPlaylistMode(PlaylistMode.loop);

    final startMs = widget.prefs.videoLoopStartMs ?? 0;
    final endMs = widget.prefs.videoLoopEndMs;

    // Enforce trim boundaries on every position tick.
    //
    // • pos < startMs  — jump to startMs (covers initial play from 0 and any
    //                    case where PlaylistMode.loop resets to 0 after endMs).
    // • pos >= endMs   — seek back to startMs (custom loop end).
    //
    // The FadeTransition starts at opacity 0, so any brief rendering at
    // position 0 before the first seek (<33 ms) is invisible to the user.
    _player.stream.position.listen((pos) {
      if (!mounted) return;
      final ms = pos.inMilliseconds;
      if (startMs > 0 && ms < startMs && ms >= 0) {
        _player.seek(Duration(milliseconds: startMs));
        return;
      }
      if (endMs != null && ms >= endMs) {
        _player.seek(Duration(milliseconds: startMs));
      }
    });

    _player.stream.playing.listen((playing) {
      if (playing && mounted) _fadeController.forward();
    });

    _player.open(Media(widget.videoUri));
  }

  @override
  void didUpdateWidget(VideoBackgroundPlayer old) {
    super.didUpdateWidget(old);
    if (old.videoUri != widget.videoUri) {
      _fadeController.reset();
      _player.dispose();
      _initPlayer();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Video(
        controller: _controller,
        fit: BoxFit.cover,
        controls: NoVideoControls,
      ),
    );
  }
}
