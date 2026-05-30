namespace PcIfy.Server.Constants;

public static class MediaTypes
{
    private static readonly Dictionary<string, string> MimeMap = new(StringComparer.OrdinalIgnoreCase)
    {
        // Video
        [".mp4"]  = "video/mp4",
        [".mkv"]  = "video/x-matroska",
        [".avi"]  = "video/x-msvideo",
        [".mov"]  = "video/quicktime",
        [".wmv"]  = "video/x-ms-wmv",
        [".flv"]  = "video/x-flv",
        [".webm"] = "video/webm",
        [".m4v"]  = "video/x-m4v",
        [".3gp"]  = "video/3gpp",
        // Image
        [".jpg"]  = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".png"]  = "image/png",
        [".gif"]  = "image/gif",
        [".bmp"]  = "image/bmp",
        [".webp"] = "image/webp",
        [".heic"] = "image/heic",
        [".tiff"] = "image/tiff",
        // Audio
        [".mp3"]  = "audio/mpeg",
        [".flac"] = "audio/flac",
        [".aac"]  = "audio/aac",
        [".ogg"]  = "audio/ogg",
        [".wav"]  = "audio/wav",
        [".m4a"]  = "audio/mp4",
        // Document
        [".pdf"]  = "application/pdf",
        [".txt"]  = "text/plain",
        [".zip"]  = "application/zip",
    };

    public static string GetMimeType(string extension) =>
        MimeMap.TryGetValue(extension, out var mime) ? mime : "application/octet-stream";

    public static bool IsVideo(string extension) =>
        MimeMap.TryGetValue(extension, out var mime) && mime.StartsWith("video/");

    public static bool IsImage(string extension) =>
        MimeMap.TryGetValue(extension, out var mime) && mime.StartsWith("image/");

    public static bool IsAudio(string extension) =>
        MimeMap.TryGetValue(extension, out var mime) && mime.StartsWith("audio/");

    public static bool IsThumbnailable(string extension) =>
        IsVideo(extension) || IsImage(extension);
}
