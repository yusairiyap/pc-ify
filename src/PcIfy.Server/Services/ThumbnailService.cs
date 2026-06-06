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

    // Legacy size-based overload (backward compat)
    public async Task<string?> GetOrCreateThumbnailAsync(string filePath, ThumbnailSize size)
    {
        var quality = size switch
        {
            ThumbnailSize.Small  => 25,
            ThumbnailSize.Large  => 100,
            _                    => 50
        };
        return await GetOrCreateThumbnailAsync(filePath, quality, null);
    }

    public async Task<string?> GetOrCreateThumbnailAsync(string filePath, int quality, double? atSeconds = null)
    {
        if (!File.Exists(filePath)) return null;

        quality = Math.Clamp(quality, 10, 100);
        var ext = Path.GetExtension(filePath);
        var cachePath = GetCachePath(filePath, quality, atSeconds);

        if (File.Exists(cachePath)) return cachePath;

        var maxDim = (int)Math.Clamp(quality / 100.0 * 512, 32, 512);
        var jpegQuality = (int)Math.Clamp(60 + quality * 0.35, 60, 95);

        if (MediaTypes.IsImage(ext))
            return await CreateImageThumbnailAsync(filePath, cachePath, maxDim, jpegQuality);

        if (MediaTypes.IsVideo(ext))
            return await CreateVideoThumbnailAsync(filePath, cachePath, maxDim, jpegQuality, atSeconds ?? 2.0);

        return null;
    }

    public async Task<long?> GetVideoDurationMsAsync(string filePath)
    {
        if (!File.Exists(filePath)) return null;
        try
        {
            var info = await FFProbe.AnalyseAsync(filePath);
            var ms = (long)info.Duration.TotalMilliseconds;
            return ms > 0 ? ms : null;
        }
        catch
        {
            return null;
        }
    }

    private static Task<string?> CreateImageThumbnailAsync(string sourcePath, string destPath, int maxDim, int jpegQuality = 85)
    {
        try
        {
            using var original = SKBitmap.Decode(sourcePath);
            if (original is null) return Task.FromResult<string?>(null);

            var (w, h) = ScaleDimensions(original.Width, original.Height, maxDim);
            using var resized = original.Resize(new SKImageInfo(w, h), new SKSamplingOptions(SKFilterMode.Linear, SKMipmapMode.Linear));
            using var image = SKImage.FromBitmap(resized);
            using var data = image.Encode(SKEncodedImageFormat.Jpeg, jpegQuality);
            using var fs = File.Create(destPath);
            data.SaveTo(fs);
            return Task.FromResult<string?>(destPath);
        }
        catch
        {
            return Task.FromResult<string?>(null);
        }
    }

    private static async Task<string?> CreateVideoThumbnailAsync(string sourcePath, string destPath, int maxDim, int jpegQuality, double captureSeconds)
    {
        try
        {
            var tempPath = destPath + ".tmp.jpg";
            var success = await FFMpeg.SnapshotAsync(sourcePath, tempPath, captureTime: TimeSpan.FromSeconds(captureSeconds));
            if (!success || !File.Exists(tempPath)) return null;

            await CreateImageThumbnailAsync(tempPath, destPath, maxDim, jpegQuality);
            File.Delete(tempPath);

            return File.Exists(destPath) ? destPath : null;
        }
        catch
        {
            return null;
        }
    }

    private string GetCachePath(string filePath, int quality, double? atSeconds)
    {
        var key = $"{filePath}:q{quality}:t{(atSeconds ?? 2.0):F2}";
        var hash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(key)));
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
