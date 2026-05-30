using PcIfy.Server.Helpers;
using PcIfy.Server.Models;
using PcIfy.Server.Services.Interfaces;
using PcIfy.Server.Constants;
using PcIfy.Server.DTOs.Files;

namespace PcIfy.Server.Services;

public class FileService : IFileService
{
    private readonly AppSettings _settings;

    public FileService(AppSettings settings) => _settings = settings;

    public IEnumerable<string> GetConfiguredRoots() => _settings.SourceDirectories;

    public bool IsPathAllowed(string path) =>
        PathSanitizer.IsPathAllowed(path, _settings.SourceDirectories);

    public Task<FolderListingDto> GetFolderListingAsync(string path)
    {
        var fullPath = Path.GetFullPath(path);
        var dirInfo = new DirectoryInfo(fullPath);

        var entries = new List<FileEntryDto>();

        foreach (var dir in dirInfo.GetDirectories().OrderBy(d => d.Name))
        {
            entries.Add(new FileEntryDto
            {
                Name = dir.Name,
                Path = dir.FullName,
                Type = FileType.Folder,
                LastModified = dir.LastWriteTime
            });
        }

        foreach (var file in dirInfo.GetFiles().OrderBy(f => f.Name))
        {
            var ext = file.Extension;
            var type = FileTypeHelper.GetFileType(ext);
            entries.Add(new FileEntryDto
            {
                Name = file.Name,
                Path = file.FullName,
                Type = type,
                SizeBytes = file.Length,
                LastModified = file.LastWriteTime,
                HasThumbnail = MediaTypes.IsThumbnailable(ext)
            });
        }

        var parentPath = dirInfo.Parent?.FullName;
        var isParentAllowed = parentPath is not null && IsPathAllowed(parentPath);

        return Task.FromResult(new FolderListingDto
        {
            Path = fullPath,
            ParentPath = isParentAllowed ? parentPath : null,
            DisplayName = dirInfo.Name,
            Entries = entries
        });
    }

    public Task<Stream> OpenFileStreamAsync(string path) =>
        Task.FromResult<Stream>(File.OpenRead(path));

    public FileInfo GetFileInfo(string path) => new(path);
}
