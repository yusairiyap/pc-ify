abstract final class MediaTypes {
  static const _mimeMap = {
    '.mp4': 'video/mp4',
    '.mkv': 'video/x-matroska',
    '.avi': 'video/x-msvideo',
    '.mov': 'video/quicktime',
    '.wmv': 'video/x-ms-wmv',
    '.flv': 'video/x-flv',
    '.webm': 'video/webm',
    '.m4v': 'video/mp4',
    '.ts': 'video/mp2t',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.bmp': 'image/bmp',
    '.mp3': 'audio/mpeg',
    '.aac': 'audio/aac',
    '.wav': 'audio/wav',
    '.flac': 'audio/flac',
    '.ogg': 'audio/ogg',
    '.m4a': 'audio/mp4',
    '.pdf': 'application/pdf',
    '.zip': 'application/zip',
    '.rar': 'application/x-rar-compressed',
    '.7z': 'application/x-7z-compressed',
  };

  static String getMimeType(String extension) {
    return _mimeMap[extension.toLowerCase()] ?? 'application/octet-stream';
  }

  static bool isVideo(String extension) {
    final mime = getMimeType(extension);
    return mime.startsWith('video/');
  }

  static bool isImage(String extension) {
    final mime = getMimeType(extension);
    return mime.startsWith('image/');
  }

  static bool isAudio(String extension) {
    final mime = getMimeType(extension);
    return mime.startsWith('audio/');
  }

  static bool isThumbnailable(String extension) {
    return isVideo(extension) || isImage(extension);
  }

  static String extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '';
    return name.substring(dot);
  }
}
