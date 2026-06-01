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

  // The Video widget is kept out of the tree entirely until the player is
  // confirmed at the correct position, which prevents the native texture from
  // ever flashing frame 0 — no overlay widget can guarantee that.
  bool _showVideo = false;

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

    bool revealed = false;
    _player.stream.position.listen((pos) {
      if (!mounted) return;
      final ms = pos.inMilliseconds;

      // Jump to trim start: covers initial play-from-0 and PlaylistMode.loop
      // resetting to 0 after a natural loop-end.
      if (startMs > 0 && ms < startMs) {
        _player.seek(Duration(milliseconds: startMs));
        return;
      }
      // Jump back to trim start at the custom loop end.
      if (endMs != null && ms >= endMs) {
        _player.seek(Duration(milliseconds: startMs));
        return;
      }

      // Position is in the valid range — add the Video widget then fade in.
      // Doing both together ensures the texture is already at the correct
      // position when it first appears on screen.
      if (!revealed) {
        revealed = true;
        setState(() => _showVideo = true);
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
      setState(() => _showVideo = false);
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
    if (!_showVideo) return const SizedBox.shrink();
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
