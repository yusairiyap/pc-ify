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
    _player.open(Media(widget.videoUri));

    _player.stream.playing.listen((playing) {
      if (playing && mounted) _fadeController.forward();
    });

    final startMs = widget.prefs.videoLoopStartMs;
    final endMs = widget.prefs.videoLoopEndMs;
    if (startMs != null || endMs != null) {
      // Seek to the trim start once the duration is known
      if (startMs != null && startMs > 0) {
        var didSeekToStart = false;
        _player.stream.duration.listen((d) {
          if (!mounted || didSeekToStart || d.inMilliseconds == 0) return;
          didSeekToStart = true;
          _player.seek(Duration(milliseconds: startMs));
        });
      }
      _player.stream.position.listen((pos) {
        if (!mounted) return;
        final end = endMs;
        final start = startMs ?? 0;
        if (end != null && pos.inMilliseconds >= end) {
          _player.seek(Duration(milliseconds: start));
        }
      });
    }
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
