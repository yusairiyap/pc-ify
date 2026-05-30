using PcIfy.Server.Constants;
using PcIfy.Server.DTOs.Files;

namespace PcIfy.Server.Helpers;

public static class FileTypeHelper
{
    public static FileType GetFileType(string extension)
    {
        if (MediaTypes.IsVideo(extension)) return FileType.Video;
        if (MediaTypes.IsImage(extension)) return FileType.Image;
        if (MediaTypes.IsAudio(extension)) return FileType.Audio;

        return extension.ToLowerInvariant() switch
        {
            ".pdf" or ".txt" or ".doc" or ".docx" or ".xls" or ".xlsx" => FileType.Document,
            ".zip" or ".rar" or ".7z" or ".tar" or ".gz"               => FileType.Archive,
            _                                                            => FileType.Unknown,
        };
    }
}
