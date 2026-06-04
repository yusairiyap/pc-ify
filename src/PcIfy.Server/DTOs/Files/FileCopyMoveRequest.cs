namespace PcIfy.Server.DTOs.Files;

public class FileCopyMoveRequest
{
    public string Src { get; set; } = string.Empty;
    public string DestFolder { get; set; } = string.Empty;
}
