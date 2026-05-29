namespace PcIfy.Client.Services.Interfaces;

public interface IConnectionService
{
    string? BaseUrl { get; }
    bool IsConfigured { get; }
    Task SetConnectionAsync(string host, int port);
    Task<bool> TestConnectionAsync();
}
