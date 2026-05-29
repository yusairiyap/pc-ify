namespace PcIfy.Client.Models;

public class FolderPrefs
{
    public string? BackgroundFilePath { get; set; }
    public float CropX { get; set; }
    public float CropY { get; set; }
    public float CropWidth { get; set; } = 1f;
    public float CropHeight { get; set; } = 1f;
    public float ZoomLevel { get; set; } = 1f;
}
