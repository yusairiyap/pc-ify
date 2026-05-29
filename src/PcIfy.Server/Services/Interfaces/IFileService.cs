using PcIfy.Shared.DTOs.Files;

namespace PcIfy.Server.Services.Interfaces;

public interface IFileService
{
    Task<FolderListingDto> GetFolderListingAsync(string path);
    IEnumerable<string> GetConfiguredRoots();
    Task<Stream> OpenFileStreamAsync(string path);
    FileInfo GetFileInfo(string path);
    bool IsPathAllowed(string path);
}
