// Basic smoke tests for pcify_server.
// Full widget tests require platform channels (shelf server, file_picker, etc.)
// which are not available in the test environment, so this file is intentionally
// kept as unit-level tests only.

import 'package:flutter_test/flutter_test.dart';
import 'package:pcify_server/core/utils/path_sanitizer.dart';
import 'package:pcify_server/core/constants/media_types.dart';

void main() {
  group('PathSanitizer', () {
    test('allows path inside an allowed root', () {
      expect(
        PathSanitizer.isPathAllowed('/media/movies/film.mp4', ['/media/movies']),
        isTrue,
      );
    });

    test('blocks path outside allowed roots', () {
      expect(
        PathSanitizer.isPathAllowed('/etc/passwd', ['/media/movies']),
        isFalse,
      );
    });

    test('blocks path traversal attempt', () {
      expect(
        PathSanitizer.isPathAllowed(
            '/media/movies/../../etc/passwd', ['/media/movies']),
        isFalse,
      );
    });
  });

  group('MediaTypes', () {
    test('identifies video extensions', () {
      expect(MediaTypes.isVideo('mp4'), isTrue);
      expect(MediaTypes.isVideo('mkv'), isTrue);
      expect(MediaTypes.isVideo('txt'), isFalse);
    });

    test('identifies image extensions', () {
      expect(MediaTypes.isImage('jpg'), isTrue);
      expect(MediaTypes.isImage('png'), isTrue);
      expect(MediaTypes.isImage('mp4'), isFalse);
    });

    test('returns correct MIME type', () {
      expect(MediaTypes.getMimeType('mp4'), equals('video/mp4'));
      expect(MediaTypes.getMimeType('jpg'), equals('image/jpeg'));
      expect(MediaTypes.getMimeType('unknown_ext'), equals('application/octet-stream'));
    });
  });
}
