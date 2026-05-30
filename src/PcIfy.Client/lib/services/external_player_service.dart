import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalPlayerService {
  Future<bool> canOpenExternally() async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isWindows || Platform.isMacOS) {
      return true;
    }
    return false;
  }

  Future<void> openVideo(String uri, String mimeType) async {
    if (Platform.isAndroid) {
      final intent = AndroidIntent(
        action: 'action_view',
        data: uri,
        type: mimeType,
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return;
    }

    if (Platform.isIOS) {
      final vlcUri = uri.replaceFirst(RegExp(r'^https?://'), 'vlc-x-callback://x-callback-url/stream?url=');
      final parsed = Uri.tryParse(vlcUri);
      if (parsed != null && await canLaunchUrl(parsed)) {
        await launchUrl(parsed, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final parsed = Uri.tryParse(uri);
    if (parsed != null) {
      await launchUrl(parsed, mode: LaunchMode.externalApplication);
    }
  }
}
