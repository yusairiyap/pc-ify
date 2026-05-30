import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/constants/media_types.dart';
import '../../providers/services_providers.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen(
      {super.key, required this.filePath, required this.fileName});
  final String filePath;
  final String fileName;

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  String? _streamUri;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    _initStream();
  }

  Future<void> _initStream() async {
    final api = ref.read(apiServiceProvider);
    final uri = await api.buildStreamUriWithToken(widget.filePath);
    setState(() => _streamUri = uri);
    await _player.open(Media(uri));
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _player.dispose();
    super.dispose();
  }

  Future<void> _openExternal() async {
    if (_streamUri == null) return;
    final mime = MediaTypes.getMimeType(MediaTypes.extensionOf(widget.fileName));
    await ref.read(externalPlayerServiceProvider).openVideo(_streamUri!, mime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.fileName,
            style: const TextStyle(fontSize: 14, color: Colors.white70)),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            tooltip: 'Open in external player',
            onPressed: _openExternal,
          ),
        ],
      ),
      body: _streamUri == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : MaterialVideoControlsTheme(
              normal: const MaterialVideoControlsThemeData(
                seekBarHeight: 8,
                seekBarThumbSize: 22,
                seekBarContainerHeight: 96,
              ),
              fullscreen: const MaterialVideoControlsThemeData(
                seekBarHeight: 8,
                seekBarThumbSize: 22,
                seekBarContainerHeight: 96,
              ),
              child: Video(controller: _controller),
            ),
    );
  }
}
