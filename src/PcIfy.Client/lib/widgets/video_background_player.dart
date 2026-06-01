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

    // Enforce trim boundaries and delay the fade-in until the video is
    // actually at the correct position (prevents showing position 0).
    bool fadedIn = false;
    _player.stream.position.listen((pos) {
      if (!mounted) return;
      final ms = pos.inMilliseconds;

      // Jump to trim start: covers initial play-from-0 and PlaylistMode.loop
      // resetting to 0 after a natural loop-end.
      if (startMs > 0 && ms < startMs) {
        _player.seek(Duration(milliseconds: startMs));
        return; // don't fade in yet
      }
      // Jump back to trim start at the custom loop end.
      if (endMs != null && ms >= endMs) {
        _player.seek(Duration(milliseconds: startMs));
        return; // don't fade in yet
      }

      // Position is in the valid range — start the fade on the first valid tick.
      if (!fadedIn) {
        fadedIn = true;
        _fadeController.forward();
      }
    });

    _player.open(Media(widget.videoUri));
  }

  @override
  void didUpdateWidget(VideoBackgroundPlayer old) {
    super.didUpdateWidget(old);
    if (old.videoUri != widget.videoUri ||
        old.prefs.videoLoopStartMs != widget.prefs.videoLoopStartMs ||
        old.prefs.videoLoopEndMs != widget.prefs.videoLoopEndMs) {
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
