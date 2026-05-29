namespace PcIfy.Client.Models;

public class BookmarkedFolder
{
    public string Path { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? CoverThumbnailServerPath { get; set; }
}
