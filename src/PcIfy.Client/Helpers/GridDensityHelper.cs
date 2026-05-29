using PcIfy.Client.Models;

namespace PcIfy.Client.Helpers;

public static class GridDensityHelper
{
    public static int GetColumnCount(double screenWidth, GridDensity density)
    {
        return density switch
        {
            GridDensity.Compact => screenWidth switch { > 1200 => 8, > 800 => 6, > 600 => 5, > 400 => 4, _ => 3 },
            GridDensity.Large   => screenWidth switch { > 1200 => 4, > 800 => 3, > 600 => 3, _ => 2 },
            _                   => screenWidth switch { > 1200 => 6, > 800 => 5, > 600 => 4, > 400 => 3, _ => 2 },
        };
    }

    public static double GetItemSize(double screenWidth, GridDensity density)
    {
        var cols = GetColumnCount(screenWidth, density);
        return (screenWidth - (cols + 1) * 8) / cols;
    }
}
