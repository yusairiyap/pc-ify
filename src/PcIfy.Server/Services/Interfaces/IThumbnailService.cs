namespace PcIfy.Server.Services.Interfaces;

public enum ThumbnailSize { Small = 128, Medium = 256, Large = 512 }

public interface IThumbnailService
{
    Task<string?> GetOrCreateThumbnailAsync(string filePath, ThumbnailSize size);
    Task<string?> GetOrCreateThumbnailAsync(string filePath, int quality, double? atSeconds = null);
    Task<long?> GetVideoDurationMsAsync(string filePath);
}
