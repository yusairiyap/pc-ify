namespace PcIfy.Client.Models;

public enum GridDensity { Compact, Normal, Large }

public class AppPreferences
{
    public string Theme { get; set; } = "System";
    public string AccentColor { get; set; } = "#6750A4";
    public GridDensity DefaultGridDensity { get; set; } = GridDensity.Normal;
}
