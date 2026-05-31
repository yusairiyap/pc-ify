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

class _VideoBackgroundPlayerState extends State<VideoBackgroundPlayer> {
  late Player _player;
  late VideoController _controller;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _player = Player();
    _controller = VideoController(_player);
    _player.setVolume(0);
    _player.setPlaylistMode(PlaylistMode.loop);
    _player.open(Media(widget.videoUri));

    final startMs = widget.prefs.videoLoopStartMs;
    final endMs = widget.prefs.videoLoopEndMs;
    if (startMs != null || endMs != null) {
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
      _player.dispose();
      _initPlayer();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: _controller,
      fit: BoxFit.cover,
      controls: NoVideoControls,
    );
  }
}
