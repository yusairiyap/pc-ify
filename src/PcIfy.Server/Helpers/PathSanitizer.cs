namespace PcIfy.Server.Helpers;

public static class PathSanitizer
{
    public static bool IsPathAllowed(string requestedPath, IEnumerable<string> allowedRoots)
    {
        try
        {
            var full = Path.GetFullPath(requestedPath);
            return allowedRoots.Any(root =>
            {
                var fullRoot = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
                return full.StartsWith(fullRoot, StringComparison.OrdinalIgnoreCase)
                    || string.Equals(full, fullRoot.TrimEnd(Path.DirectorySeparatorChar), StringComparison.OrdinalIgnoreCase);
            });
        }
        catch
        {
            return false;
        }
    }

    public static string? Sanitize(string requestedPath, IEnumerable<string> allowedRoots)
    {
        try
        {
            var full = Path.GetFullPath(requestedPath);
            return IsPathAllowed(full, allowedRoots) ? full : null;
        }
        catch
        {
            return null;
        }
    }
}
