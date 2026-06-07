namespace PcIfy.Server.Models;

public class AppSettings
{
    public int Port { get; set; } = 8080;
    public bool AutoStart { get; set; } = true;
    public string ServerName { get; set; } = Environment.MachineName;
    public string JwtSecret { get; set; } = Guid.NewGuid().ToString("N") + Guid.NewGuid().ToString("N");
    public int TokenExpiryHours { get; set; } = 24;
    public List<UserCredential> Users { get; set; } = [];
    public List<string> SourceDirectories { get; set; } = [];
    public string ColorMode { get; set; } = "System";
    public List<LauncherApp> LauncherApps { get; set; } = [];
}

public class LauncherApp
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string ExecutablePath { get; set; } = "";
    public string? ProcessName { get; set; }
    public string? IconKey { get; set; }
}
