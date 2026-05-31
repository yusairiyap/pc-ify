import 'dart:io';
import 'package:path/path.dart' as p;

abstract final class PathSanitizer {
  /// Returns true if [path] is under one of the [allowedRoots].
  static bool isPathAllowed(String path, List<String> allowedRoots) {
    try {
      // resolveSymbolicLinksSync follows symlinks so a symlink inside an
      // allowed root that points outside it is correctly rejected.
      // Falls back to absolute + normalize for non-existent paths (e.g. during
      // a write that hasn't happened yet) since resolveSymbolicLinks requires
      // the path to exist on most platforms.
      final normalized = _resolve(path);
      return allowedRoots.any((root) {
        final normalizedRoot = _resolve(root);
        final rootWithSep = normalizedRoot + Platform.pathSeparator;
        return normalized.toLowerCase().startsWith(rootWithSep.toLowerCase()) ||
            normalized.toLowerCase() == normalizedRoot.toLowerCase();
      });
    } catch (_) {
      return false;
    }
  }

  /// Returns the resolved absolute path if allowed, null otherwise.
  static String? sanitize(String path, List<String> allowedRoots) {
    if (!isPathAllowed(path, allowedRoots)) return null;
    return _resolve(path);
  }

  static String _resolve(String path) {
    try {
      return File(path).resolveSymbolicLinksSync();
    } catch (_) {
      // File doesn't exist yet — fall back to lexical normalisation.
      return p.normalize(File(path).absolute.path);
    }
  }
}
