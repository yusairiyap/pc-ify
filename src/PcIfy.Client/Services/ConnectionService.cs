using PcIfy.Client.Services.Interfaces;
using PcIfy.Shared.Constants;

namespace PcIfy.Client.Services;

public class ConnectionService : IConnectionService
{
    private const string BaseUrlKey = "server_base_url";
    private readonly HttpClient _http;

    public ConnectionService(HttpClient http)
    {
        _http = http;
        BaseUrl = Preferences.Get(BaseUrlKey, null);
    }

    public string? BaseUrl { get; private set; }
    public bool IsConfigured => !string.IsNullOrEmpty(BaseUrl);

    public Task SetConnectionAsync(string host, int port)
    {
        BaseUrl = $"http://{host.Trim()}:{port}";
        Preferences.Set(BaseUrlKey, BaseUrl);
        // Do NOT set _http.BaseAddress — HttpClient forbids changing it after the first request.
        // ApiService builds full URIs from IConnectionService.BaseUrl instead.
        return Task.CompletedTask;
    }

    public async Task<bool> TestConnectionAsync()
    {
        if (!IsConfigured) return false;
        try
        {
            var url = $"{BaseUrl}{ApiRoutes.SystemHealth}";
            var resp = await _http.GetAsync(url).ConfigureAwait(false);
            return resp.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }
}
