namespace PcIfy.Client.Services.Interfaces;

public interface IExternalPlayerService
{
    Task<bool> CanOpenExternallyAsync(string mimeType);
    Task OpenAsync(System.Uri streamUri, string mimeType, string title);
}
