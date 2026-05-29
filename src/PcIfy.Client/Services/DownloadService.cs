using PcIfy.Client.Services.Interfaces;
using PcIfy.Shared.Constants;

namespace PcIfy.Client.Services;

public class DownloadService : IDownloadService
{
    private readonly HttpClient _http;

    public DownloadService(HttpClient http) => _http = http;

    public async Task DownloadFileAsync(string serverPath, string fileName, IProgress<double> progress, CancellationToken ct = default)
    {
        var encoded = Uri.EscapeDataString(serverPath.TrimStart('/', '\\').Replace('\\', '/'));
        var url = $"{ApiRoutes.FilesDownload}/{encoded}";

        using var resp = await _http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, ct);
        resp.EnsureSuccessStatusCode();

        var total = resp.Content.Headers.ContentLength ?? -1L;
#if WINDOWS
        var downloadsFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads");
#else
        var downloadsFolder = Path.Combine(FileSystem.AppDataDirectory, "downloads");
#endif
        var destPath = Path.Combine(downloadsFolder, fileName);
        Directory.CreateDirectory(Path.GetDirectoryName(destPath)!);

        await using var source = await resp.Content.ReadAsStreamAsync(ct);
        await using var dest = File.Create(destPath);

        var buffer = new byte[81920];
        long read = 0;
        int bytesRead;
        while ((bytesRead = await source.ReadAsync(buffer, ct)) > 0)
        {
            await dest.WriteAsync(buffer.AsMemory(0, bytesRead), ct);
            read += bytesRead;
            if (total > 0) progress.Report((double)read / total);
        }
    }
}
