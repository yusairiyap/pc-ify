import '../constants/media_types.dart';

enum FileType { unknown, folder, video, image, audio, document, archive }

abstract final class FileTypeHelper {
  static const _docExts = {'pdf', 'txt', 'doc', 'docx', 'xls', 'xlsx'};
  static const _archiveExts = {'zip', 'rar', '7z', 'tar', 'gz'};

  static FileType fromExtension(String extension) {
    final ext = extension.toLowerCase().replaceFirst('.', '');
    if (MediaTypes.isVideo(ext)) return FileType.video;
    if (MediaTypes.isImage(ext)) return FileType.image;
    if (MediaTypes.isAudio(ext)) return FileType.audio;
    if (_docExts.contains(ext)) return FileType.document;
    if (_archiveExts.contains(ext)) return FileType.archive;
    return FileType.unknown;
  }
}
