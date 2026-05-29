using PcIfy.Shared.DTOs.Auth;
using PcIfy.Shared.DTOs.Files;
using PcIfy.Shared.DTOs.System;

namespace PcIfy.Client.Services.Interfaces;

public interface IApiService
{
    Task<LoginResponse?> LoginAsync(string username, string password);
    Task<FolderListingDto?> GetFolderListingAsync(string path);
    Task<IEnumerable<string>> GetRootsAsync();
    Task<Stream?> StreamFileAsync(string serverPath, (long start, long end)? range = null);
    Uri GetStreamUri(string serverPath);
    Uri GetThumbnailUri(string serverPath, string size = "medium");
    Task<ServerInfoDto?> GetServerInfoAsync();
    Task<bool> PingAsync();
}
