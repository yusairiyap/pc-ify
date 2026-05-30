using FFMpegCore;
using PcIfy.Server.Services.Interfaces;
using PcIfy.Server.Constants;
using SkiaSharp;

namespace PcIfy.Server.Services;

public class ThumbnailService : IThumbnailService
{
    private readonly string _cacheDir;

    public ThumbnailService()
    {
        _cacheDir = Path.Combine(Path.GetTempPath(), "pcify-thumbs");
        Directory.CreateDirectory(_cacheDir);
        FFmpegSetupService.Configure();
    }

    public async Task<string?> GetOrCreateThumbnailAsync(string filePath, ThumbnailSize size)
    {
        if (!File.Exists(filePath)) return null;

        var ext = Path.GetExtension(filePath);
        var cachePath = GetCachePath(filePath, size);

        if (File.Exists(cachePath)) return cachePath;

        if (MediaTypes.IsImage(ext))
            return await CreateImageThumbnailAsync(filePath, cachePath, (int)size);

        if (MediaTypes.IsVideo(ext))
            return await CreateVideoThumbnailAsync(filePath, cachePath, (int)size);

        return null;
    }

    private static Task<string?> CreateImageThumbnailAsync(string sourcePath, string destPath, int maxDim)
    {
        try
        {
            using var original = SKBitmap.Decode(sourcePath);
            if (original is null) return Task.FromResult<string?>(null);

            var (w, h) = ScaleDimensions(original.Width, original.Height, maxDim);
            using var resized = original.Resize(new SKImageInfo(w, h), new SKSamplingOptions(SKFilterMode.Linear, SKMipmapMode.Linear));
            using var image = SKImage.FromBitmap(resized);
            using var data = image.Encode(SKEncodedImageFormat.Jpeg, 85);
            using var fs = File.Create(destPath);
            data.SaveTo(fs);
            return Task.FromResult<string?>(destPath);
        }
        catch
        {
            return Task.FromResult<string?>(null);
        }
    }

    private static async Task<string?> CreateVideoThumbnailAsync(string sourcePath, string destPath, int maxDim)
    {
        try
        {
            var tempPath = destPath + ".tmp.jpg";
            var success = await FFMpeg.SnapshotAsync(sourcePath, tempPath, captureTime: TimeSpan.FromSeconds(2));
            if (!success || !File.Exists(tempPath)) return null;

            await CreateImageThumbnailAsync(tempPath, destPath, maxDim);
            File.Delete(tempPath);

            return File.Exists(destPath) ? destPath : null;
        }
        catch
        {
            return null;
        }
    }

    private string GetCachePath(string filePath, ThumbnailSize size)
    {
        var hash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(filePath + size)));
        return Path.Combine(_cacheDir, hash + ".jpg");
    }

    private static (int width, int height) ScaleDimensions(int w, int h, int maxDim)
    {
        if (w <= maxDim && h <= maxDim) return (w, h);
        if (w > h)
            return (maxDim, (int)(h * (double)maxDim / w));
        return ((int)(w * (double)maxDim / h), maxDim);
    }
}
