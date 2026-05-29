using System.Net.Http.Json;
using PcIfy.Client.Services.Interfaces;
using PcIfy.Shared.Constants;
using PcIfy.Shared.DTOs.Auth;
using PcIfy.Shared.DTOs.Files;
using PcIfy.Shared.DTOs.System;

namespace PcIfy.Client.Services;

public class ApiService : IApiService
{
    private readonly HttpClient _http;
    private readonly IAuthTokenService _tokenService;
    private readonly IConnectionService _connection;

    public ApiService(HttpClient http, IAuthTokenService tokenService, IConnectionService connection)
    {
        _http = http;
        _tokenService = tokenService;
        _connection = connection;
    }

    public async Task<LoginResponse?> LoginAsync(string username, string password)
    {
        try
        {
            var resp = await _http.PostAsJsonAsync(
                BuildUri(ApiRoutes.AuthLogin),
                new LoginRequest { Username = username, Password = password });
            return resp.IsSuccessStatusCode ? await resp.Content.ReadFromJsonAsync<LoginResponse>() : null;
        }
        catch { return null; }
    }

    public async Task<FolderListingDto?> GetFolderListingAsync(string path)
    {
        try
        {
            var encoded = Uri.EscapeDataString(path);
            return await _http.GetFromJsonAsync<FolderListingDto>(
                BuildUri($"{ApiRoutes.FilesList}?path={encoded}"));
        }
        catch { return null; }
    }

    public async Task<IEnumerable<string>> GetRootsAsync()
    {
        try
        {
            var results = await _http.GetFromJsonAsync<IEnumerable<RootEntry>>(BuildUri(ApiRoutes.FilesRoots));
            return results?.Select(r => r.Path) ?? [];
        }
        catch { return []; }
    }

    public async Task<Stream?> StreamFileAsync(string serverPath, (long start, long end)? range = null)
    {
        try
        {
            var request = new HttpRequestMessage(HttpMethod.Get, GetStreamUri(serverPath));
            if (range.HasValue)
                request.Headers.Range = new System.Net.Http.Headers.RangeHeaderValue(range.Value.start, range.Value.end);
            var resp = await _http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);
            return resp.IsSuccessStatusCode ? await resp.Content.ReadAsStreamAsync() : null;
        }
        catch { return null; }
    }

    public Uri GetStreamUri(string serverPath)
    {
        var encoded = Uri.EscapeDataString(serverPath.TrimStart('/', '\\').Replace('\\', '/'));
        return BuildUri($"{ApiRoutes.FilesStream}/{encoded}");
    }

    public Uri GetThumbnailUri(string serverPath, string size = "medium")
    {
        var encoded = Uri.EscapeDataString(serverPath.TrimStart('/', '\\').Replace('\\', '/'));
        return BuildUri($"{ApiRoutes.Thumbnails}/{encoded}?size={size}");
    }

    public async Task<ServerInfoDto?> GetServerInfoAsync()
    {
        try { return await _http.GetFromJsonAsync<ServerInfoDto>(BuildUri(ApiRoutes.SystemInfo)); }
        catch { return null; }
    }

    public async Task<bool> PingAsync()
    {
        try
        {
            var resp = await _http.GetAsync(BuildUri(ApiRoutes.SystemHealth));
            return resp.IsSuccessStatusCode;
        }
        catch { return false; }
    }

    // Build a full URI from IConnectionService.BaseUrl + relative path.
    // Never uses HttpClient.BaseAddress — that property cannot be changed after the
    // first request has been sent, making it unsuitable for a user-configurable server URL.
    private Uri BuildUri(string path)
    {
        var baseUrl = _connection.BaseUrl?.TrimEnd('/') ?? string.Empty;
        return new Uri(baseUrl + path);
    }

    private record RootEntry(string Path, string Name);
}
