namespace PcIfy.Shared.DTOs.Files;

public class FileEntryDto
{
    public string Name { get; set; } = string.Empty;
    public string Path { get; set; } = string.Empty;
    public FileType Type { get; set; }
    public long SizeBytes { get; set; }
    public DateTime LastModified { get; set; }
    public bool HasThumbnail { get; set; }
}
