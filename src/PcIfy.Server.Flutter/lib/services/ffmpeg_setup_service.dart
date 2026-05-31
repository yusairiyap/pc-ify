import 'dart:async';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef ProgressCallback = void Function(String message, int percent);

/// Manages FFmpeg binary download on Windows and macOS.
/// On Android/iOS this class is a no-op (thumbnails use native video APIs).
class FFmpegSetupService {
  static String? _ffmpegPath;

  static String? get ffmpegPath => _ffmpegPath;

  static Future<void> configure() async {
    if (!Platform.isWindows && !Platform.isMacOS) return;

    final dir = await getApplicationSupportDirectory();
    final binDir = Directory(p.join(dir.path, 'ffmpeg'));

    final exe = Platform.isWindows
        ? p.join(binDir.path, 'ffmpeg.exe')
        : p.join(binDir.path, 'ffmpeg');

    if (File(exe).existsSync()) {
      _ffmpegPath = exe;
    }
  }

  static bool get isAvailable =>
      _ffmpegPath != null && File(_ffmpegPath!).existsSync();

  static Future<void> ensureAvailable(ProgressCallback onProgress) async {
    if (!Platform.isWindows && !Platform.isMacOS) return;
    if (isAvailable) return;

    final dir = await getApplicationSupportDirectory();
    final binDir = Directory(p.join(dir.path, 'ffmpeg'));
    await binDir.create(recursive: true);

    if (Platform.isWindows) {
      await _downloadWindows(binDir.path, onProgress);
    } else {
      await _downloadMacOs(binDir.path, onProgress);
    }

    await configure();
  }

  // ── Windows: BtbN GPL-shared ZIP ─────────────────────────────────────────

  static const _windowsUrl =
      'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/'
      'ffmpeg-master-latest-win64-gpl-shared.zip';

  static Future<void> _downloadWindows(
      String binDir, ProgressCallback onProgress) async {
    onProgress('Downloading FFmpeg…', 0);
    final zipPath = p.join(binDir, 'ffmpeg.zip');
    await _downloadFile(_windowsUrl, zipPath, onProgress, maxPercent: 85);

    onProgress('Extracting…', 90);
    final zipFile = File(zipPath);
    final bytes = zipFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = p.basename(file.name);
      // Extract ffmpeg.exe and DLLs from the bin/ subdirectory.
      if (!file.name.contains('/bin/')) continue;
      final outFile = File(p.join(binDir, name));
      outFile.writeAsBytesSync(file.content as List<int>);
    }
    await zipFile.delete();
    onProgress('Ready', 100);
  }

  // ── macOS: static single-binary build ────────────────────────────────────

  static const _macOsUrl =
      'https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip';

  static Future<void> _downloadMacOs(
      String binDir, ProgressCallback onProgress) async {
    onProgress('Downloading FFmpeg…', 0);
    final zipPath = p.join(binDir, 'ffmpeg.zip');
    await _downloadFile(_macOsUrl, zipPath, onProgress, maxPercent: 85);

    onProgress('Extracting…', 90);
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = p.basename(file.name);
      if (name != 'ffmpeg') continue;
      final out = File(p.join(binDir, 'ffmpeg'));
      out.writeAsBytesSync(file.content as List<int>);
      await Process.run('chmod', ['+x', out.path]);
    }
    await File(zipPath).delete();
    onProgress('Ready', 100);
  }

  // ── Generic download with progress ───────────────────────────────────────

  static Future<void> _downloadFile(
    String url,
    String destPath,
    ProgressCallback onProgress, {
    int maxPercent = 100,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = File(destPath).openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          final pct = ((received / total) * maxPercent).round();
          onProgress('Downloading… ${(received / 1048576).toStringAsFixed(1)} MB', pct);
        }
      }
      await sink.close();
    } finally {
      client.close();
    }
  }
}
