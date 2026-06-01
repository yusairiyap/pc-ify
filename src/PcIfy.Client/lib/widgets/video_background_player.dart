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

    _player.stream.playing.listen((playing) {
      if (playing && mounted) _fadeController.forward();
    });

    final startMs = widget.prefs.videoLoopStartMs;
    final endMs = widget.prefs.videoLoopEndMs;

    // Loop enforcement: seek back to trim start when trim end is reached
    if (endMs != null) {
      _player.stream.position.listen((pos) {
        if (!mounted) return;
        final start = startMs ?? 0;
        if (pos.inMilliseconds >= endMs) {
          _player.seek(Duration(milliseconds: start));
        }
      });
    }

    if (startMs != null && startMs > 0) {
      // Open without auto-play so the video never renders position 0.
      // Once the duration stream fires (media header parsed), seek to the
      // trim start and only then begin playback.
      var seeked = false;
      _player.stream.duration.listen((d) {
        if (seeked || d.inMilliseconds == 0 || !mounted) return;
        seeked = true;
        _player.seek(Duration(milliseconds: startMs)).then((_) {
          if (mounted) _player.play();
        });
      });
      _player.open(Media(widget.videoUri), play: false);
    } else {
      _player.open(Media(widget.videoUri));
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
