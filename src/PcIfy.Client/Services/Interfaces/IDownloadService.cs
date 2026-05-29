namespace PcIfy.Client.Services.Interfaces;

public interface IDownloadService
{
    Task DownloadFileAsync(string serverPath, string fileName, IProgress<double> progress, CancellationToken ct = default);
}
