using System.IO.Compression;
using FFMpegCore;

namespace PcIfy.Server.Services;

/// <summary>
/// Downloads FFmpeg binaries on first run if they're not already present.
/// Uses the BtbN/FFmpeg-Builds release (GPL essentials, Windows x64).
/// </summary>
public static class FFmpegSetupService
{
    private static readonly string FfmpegDir = Path.Combine(AppContext.BaseDirectory, "ffmpeg");
    private static readonly string FfmpegExe = Path.Combine(FfmpegDir, "ffmpeg.exe");
    private static readonly string FfprobeExe = Path.Combine(FfmpegDir, "ffprobe.exe");

    // Latest essentials build — GPL, Windows x64, ~30 MB zipped
    private const string DownloadUrl =
        "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip";

    public static bool IsAvailable => File.Exists(FfmpegExe) && File.Exists(FfprobeExe);

    public static void Configure()
    {
        if (IsAvailable)
            GlobalFFOptions.Configure(opts => opts.BinaryFolder = FfmpegDir);
    }

    public static async Task EnsureAvailableAsync(IProgress<(string message, int percent)>? progress = null)
    {
        if (IsAvailable)
        {
            Configure();
            return;
        }

        Directory.CreateDirectory(FfmpegDir);

        var zipPath = Path.Combine(Path.GetTempPath(), "ffmpeg-build.zip");

        progress?.Report(("Downloading FFmpeg…", 0));
        await DownloadWithProgressAsync(DownloadUrl, zipPath, progress);

        progress?.Report(("Extracting FFmpeg…", 90));
        await ExtractBinariesAsync(zipPath, FfmpegDir);

        if (File.Exists(zipPath))
            File.Delete(zipPath);

        if (IsAvailable)
        {
            Configure();
            progress?.Report(("FFmpeg ready", 100));
        }
        else
        {
            throw new InvalidOperationException("FFmpeg extraction completed but binaries not found.");
        }
    }

    private static async Task DownloadWithProgressAsync(
        string url, string destPath, IProgress<(string, int)>? progress)
    {
        using var http = new HttpClient();
        http.Timeout = TimeSpan.FromMinutes(5);

        using var resp = await http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
        resp.EnsureSuccessStatusCode();

        var total = resp.Content.Headers.ContentLength ?? -1L;
        await using var src = await resp.Content.ReadAsStreamAsync();
        await using var dest = File.Create(destPath);

        var buffer = new byte[81920];
        long read = 0;
        int bytes;
        while ((bytes = await src.ReadAsync(buffer)) > 0)
        {
            await dest.WriteAsync(buffer.AsMemory(0, bytes));
            read += bytes;
            if (total > 0)
                progress?.Report(($"Downloading FFmpeg… {read / 1024 / 1024} MB", (int)(read * 85 / total)));
        }
    }

    private static Task ExtractBinariesAsync(string zipPath, string targetDir)
    {
        return Task.Run(() =>
        {
            using var zip = ZipFile.OpenRead(zipPath);
            foreach (var entry in zip.Entries)
            {
                var name = Path.GetFileName(entry.FullName);
                if (name is not ("ffmpeg.exe" or "ffprobe.exe")) continue;

                var dest = Path.Combine(targetDir, name);
                entry.ExtractToFile(dest, overwrite: true);
            }
        });
    }
}
