import 'dart:io';
import 'package:path/path.dart' as p;

abstract final class PathSanitizer {
  /// Returns true if [path] is under one of the [allowedRoots].
  static bool isPathAllowed(String path, List<String> allowedRoots) {
    try {
      final normalized = p.normalize(File(path).absolute.path);
      return allowedRoots.any((root) {
        final normalizedRoot =
            p.normalize(File(root).absolute.path) + Platform.pathSeparator;
        return normalized
                .toLowerCase()
                .startsWith(normalizedRoot.toLowerCase()) ||
            normalized.toLowerCase() ==
                p
                    .normalize(File(root).absolute.path)
                    .toLowerCase();
      });
    } catch (_) {
      return false;
    }
  }

  /// Returns the normalized absolute path if allowed, null otherwise.
  static String? sanitize(String path, List<String> allowedRoots) {
    if (!isPathAllowed(path, allowedRoots)) return null;
    return p.normalize(File(path).absolute.path);
  }
}
