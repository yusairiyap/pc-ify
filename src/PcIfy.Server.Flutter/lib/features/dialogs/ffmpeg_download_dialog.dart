import 'package:flutter/material.dart';
import '../../services/ffmpeg_setup_service.dart';

class FfmpegDownloadDialog extends StatefulWidget {
  const FfmpegDownloadDialog({super.key});

  @override
  State<FfmpegDownloadDialog> createState() => _FfmpegDownloadDialogState();
}

class _FfmpegDownloadDialogState extends State<FfmpegDownloadDialog> {
  double _progress = 0;
  String _status = 'Starting download…';
  bool _done = false;
  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    await FFmpegSetupService.ensureAvailable((message, percent) {
      if (!mounted) return;
      setState(() {
        _status = message;
        _progress = percent / 100;
        _done = percent == 100;
      });
    });
    if (mounted && !_skipped) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Setting up FFmpeg'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'FFmpeg is required for video thumbnails. '
            'Downloading a ~30 MB package…',
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _done ? 1.0 : _progress),
          const SizedBox(height: 8),
          Text(_status,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        if (!_done)
          TextButton(
            onPressed: () {
              setState(() => _skipped = true);
              Navigator.pop(context, false);
            },
            child: const Text('Skip'),
          ),
      ],
    );
  }
}
