using PcIfy.Server.DTOs.Files;

namespace PcIfy.Server.Services.Interfaces;

public interface IFileService
{
    Task<FolderListingDto> GetFolderListingAsync(string path);
    IEnumerable<string> GetConfiguredRoots();
    IEnumerable<string> GetConfiguredRoots(string username);
    Task<Stream> OpenFileStreamAsync(string path);
    FileInfo GetFileInfo(string path);
    bool IsPathAllowed(string path);
    bool IsPathAllowed(string path, string username);
}
