abstract final class MediaTypes {
  static const _mimeMap = <String, String>{
    'mp4': 'video/mp4',
    'mkv': 'video/x-matroska',
    'avi': 'video/x-msvideo',
    'mov': 'video/quicktime',
    'wmv': 'video/x-ms-wmv',
    'flv': 'video/x-flv',
    'webm': 'video/webm',
    'm4v': 'video/x-m4v',
    '3gp': 'video/3gpp',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'tiff': 'image/tiff',
    'tif': 'image/tiff',
    'mp3': 'audio/mpeg',
    'flac': 'audio/flac',
    'aac': 'audio/aac',
    'ogg': 'audio/ogg',
    'wav': 'audio/wav',
    'm4a': 'audio/mp4',
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'zip': 'application/zip',
    'rar': 'application/vnd.rar',
    '7z': 'application/x-7z-compressed',
    'tar': 'application/x-tar',
    'gz': 'application/gzip',
  };

  static const _videoExts = {
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', '3gp',
  };
  static const _imageExts = {
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'tiff', 'tif',
  };
  static const _audioExts = {'mp3', 'flac', 'aac', 'ogg', 'wav', 'm4a'};

  static String getMimeType(String extension) {
    return _mimeMap[extension.toLowerCase()] ?? 'application/octet-stream';
  }

  static bool isVideo(String extension) =>
      _videoExts.contains(extension.toLowerCase());

  static bool isImage(String extension) =>
      _imageExts.contains(extension.toLowerCase());

  static bool isAudio(String extension) =>
      _audioExts.contains(extension.toLowerCase());

  static bool isThumbnailable(String extension) =>
      isVideo(extension) || isImage(extension);
}
