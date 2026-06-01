import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/folder_prefs.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/services_providers.dart';
import '../../widgets/folder_background_image.dart';
import '../../widgets/video_background_player.dart';
import '../browser/background_crop_screen.dart';
import '../browser/background_video_trim_screen.dart';
import 'dashboard_body.dart';

const _homePrefsKey = '__home__';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  FolderPrefs _prefs = const FolderPrefs();
  String? _backgroundImageUri;
  String? _backgroundVideoUri;
  ProviderSubscription<int>? _prefsVersionSub;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadBackground);
    // Reload background whenever folder prefs are bulk-changed (e.g. backup restore).
    _prefsVersionSub = ref.listenManual(
      folderPrefsVersionProvider,
      (previous, next) {
        if (previous != null && next != previous) _loadBackground();
      },
      fireImmediately: false,
    );
  }

  @override
  void dispose() {
    _prefsVersionSub?.close();
    super.dispose();
  }

  Future<void> _loadBackground() async {
    final prefs =
        await ref.read(folderPrefsServiceProvider).getPrefs(_homePrefsKey);
    if (!mounted) return;
    String? imageUri;
    if (prefs.backgroundImagePath != null) {
      imageUri = await ref
          .read(apiServiceProvider)
          .buildStreamUriWithToken(prefs.backgroundImagePath!);
    }
    String? videoUri;
    if (prefs.backgroundVideoPath != null) {
      videoUri = await ref
          .read(apiServiceProvider)
          .buildStreamUriWithToken(prefs.backgroundVideoPath!);
    }
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _backgroundImageUri = imageUri;
      _backgroundVideoUri = videoUri;
    });
  }

  Future<void> _onBackgroundTap() async {
    if (_prefs.hasBackground) {
      final isVideo = _prefs.isVideoBackground;
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  isVideo ? 'Background Video' : 'Background Image',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 1),
              if (isVideo)
                ListTile(
                  leading: const Icon(Icons.content_cut_outlined),
                  title: const Text('Trim video'),
                  onTap: () => Navigator.pop(context, 'trim'),
                )
              else
                ListTile(
                  leading: const Icon(Icons.tune_outlined),
                  title: const Text('Adjust image'),
                  onTap: () => Navigator.pop(context, 'adjust'),
                ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Change background'),
                onTap: () => Navigator.pop(context, 'change'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove background'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || action == null) return;
      if (action == 'remove') {
        await _clearBackground();
        return;
      }
      if (action == 'adjust') {
        final existingPath = _prefs.backgroundImagePath!;
        final imageUri = await ref
            .read(apiServiceProvider)
            .buildStreamUriWithToken(existingPath);
        if (!mounted) return;
        final result = await context.push<BackgroundCropResult>(
          '/background-crop?imagePath=${Uri.encodeComponent(existingPath)}',
          extra: imageUri,
        );
        if (result != null) await _saveImageBackground(result);
        return;
      }
      if (action == 'trim') {
        final existingPath = _prefs.backgroundVideoPath!;
        final videoUri = await ref
            .read(apiServiceProvider)
            .buildStreamUriWithToken(existingPath);
        if (!mounted) return;
        final result = await context.push<BackgroundVideoTrimResult>(
          '/background-video-trim',
          extra: {
            'videoUri': videoUri,
            'videoPath': existingPath,
            'startMs': _prefs.videoLoopStartMs,
            'endMs': _prefs.videoLoopEndMs,
          },
        );
        if (result != null) await _saveVideoBackground(result);
        return;
      }
      // 'change' falls through to picker
    }
    final existingPath =
        _prefs.backgroundImagePath ?? _prefs.backgroundVideoPath;
    final pickerStart = existingPath != null ? _parentOf(existingPath) : '';
    final picked = await context
        .push<String>('/image-picker?path=${Uri.encodeComponent(pickerStart)}');
    if (picked == null || !mounted) return;

    if (_isVideoPath(picked)) {
      final videoUri =
          await ref.read(apiServiceProvider).buildStreamUriWithToken(picked);
      if (!mounted) return;
      final result = await context.push<BackgroundVideoTrimResult>(
        '/background-video-trim',
        extra: {'videoUri': videoUri, 'videoPath': picked},
      );
      if (result != null) await _saveVideoBackground(result);
    } else {
      final imageUri =
          await ref.read(apiServiceProvider).buildStreamUriWithToken(picked);
      if (!mounted) return;
      final result = await context.push<BackgroundCropResult>(
        '/background-crop?imagePath=${Uri.encodeComponent(picked)}',
        extra: imageUri,
      );
      if (result != null) await _saveImageBackground(result);
    }
  }

  Future<void> _saveImageBackground(BackgroundCropResult result) async {
    final updated = FolderPrefs(
      backgroundImagePath: result.imagePath,
      cropOffsetDx: result.cropOffsetDx,
      cropOffsetDy: result.cropOffsetDy,
      cropScale: result.cropScale,
    );
    await ref
        .read(folderPrefsServiceProvider)
        .savePrefs(_homePrefsKey, updated);
    final uri = await ref
        .read(apiServiceProvider)
        .buildStreamUriWithToken(result.imagePath);
    if (!mounted) return;
    setState(() {
      _prefs = updated;
      _backgroundImageUri = uri;
      _backgroundVideoUri = null;
    });
  }

  Future<void> _saveVideoBackground(BackgroundVideoTrimResult result) async {
    final updated = FolderPrefs(
      backgroundVideoPath: result.videoPath,
      videoLoopStartMs: result.loopStartMs,
      videoLoopEndMs: result.loopEndMs,
    );
    await ref
        .read(folderPrefsServiceProvider)
        .savePrefs(_homePrefsKey, updated);
    final uri = await ref
        .read(apiServiceProvider)
        .buildStreamUriWithToken(result.videoPath);
    if (!mounted) return;
    setState(() {
      _prefs = updated;
      _backgroundImageUri = null;
      _backgroundVideoUri = uri;
    });
  }

  Future<void> _clearBackground() async {
    final updated = _prefs.copyWith(clearBackground: true);
    await ref
        .read(folderPrefsServiceProvider)
        .savePrefs(_homePrefsKey, updated);
    if (!mounted) return;
    setState(() {
      _prefs = updated;
      _backgroundImageUri = null;
      _backgroundVideoUri = null;
    });
  }

  bool _isVideoPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return {
      'mp4',
      'mkv',
      'mov',
      'avi',
      'wmv',
      'webm',
      'm4v',
      'ts',
      'flv',
      'mpeg',
      'mpg'
    }.contains(ext);
  }

  String _parentOf(String path) {
    final i = path.lastIndexOf('/');
    if (i > 0) return path.substring(0, i);
    final j = path.lastIndexOf('\\');
    if (j > 0) return path.substring(0, j);
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasBg = _backgroundImageUri != null || _backgroundVideoUri != null;

    final appBar = AppBar(
      backgroundColor: hasBg ? Colors.transparent : null,
      foregroundColor: hasBg ? Colors.white : null,
      elevation: hasBg ? 0 : null,
      title: const Text('Home'),
      actions: [
        Consumer(builder: (context, ref, _) {
          final editMode = ref.watch(dashboardEditModeProvider);
          return IconButton(
            icon: Icon(
              editMode ? Icons.check_circle_outline : Icons.tune_outlined,
              color: hasBg ? Colors.white : cs.primary,
            ),
            tooltip: editMode ? 'Done editing' : 'Customize dashboard',
            onPressed: () =>
                ref.read(dashboardEditModeProvider.notifier).state = !editMode,
          );
        }),
        IconButton(
          icon: Icon(
            _prefs.hasBackground ? Icons.wallpaper : Icons.image_outlined,
            color: hasBg ? Colors.white : cs.primary,
          ),
          tooltip:
              _prefs.hasBackground ? 'Background options' : 'Set background',
          onPressed: _onBackgroundTap,
        ),
        IconButton(
          icon:
              Icon(Icons.folder_open, color: hasBg ? Colors.white : cs.primary),
          tooltip: 'Browse All',
          onPressed: () => context.go('/browse'),
        ),
      ],
    );

    final body = DashboardBody(hasBg: hasBg);

    if (hasBg) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_backgroundVideoUri != null)
              VideoBackgroundPlayer(
                  videoUri: _backgroundVideoUri!, prefs: _prefs)
            else
              FolderBackgroundImage(
                  imageUri: _backgroundImageUri!, prefs: _prefs),
            DecoratedBox(
              decoration:
                  BoxDecoration(color: Colors.black.withValues(alpha: 0.35)),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.viewPaddingOf(context).top + kToolbarHeight,
              ),
              child: body,
            ),
          ],
        ),
      );
    }

    return Scaffold(appBar: appBar, body: body);
  }
}
