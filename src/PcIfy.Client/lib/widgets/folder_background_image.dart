import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/models/folder_prefs.dart';

class FolderBackgroundImage extends StatelessWidget {
  const FolderBackgroundImage({super.key, required this.imageUri, required this.prefs});
  final String imageUri;
  final FolderPrefs prefs;

  @override
  Widget build(BuildContext context) {
    if (!prefs.hasCrop) {
      return CachedNetworkImage(
        imageUrl: imageUri,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    final scale = prefs.cropScale ?? 1.0;
    final dx = prefs.cropOffsetDx ?? 0.0;
    final dy = prefs.cropOffsetDy ?? 0.0;
    return ClipRect(
      child: Transform(
        transform: Matrix4.identity()
          ..translateByDouble(dx, dy, 0, 1)
          ..scaleByDouble(scale, scale, 1, 1),
        child: CachedNetworkImage(
          imageUrl: imageUri,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}
