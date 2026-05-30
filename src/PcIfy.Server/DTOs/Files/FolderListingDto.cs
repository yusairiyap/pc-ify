namespace PcIfy.Server.DTOs.Files;

public class FolderListingDto
{
    public string Path { get; set; } = string.Empty;
    public string? ParentPath { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public List<FileEntryDto> Entries { get; set; } = [];
}
