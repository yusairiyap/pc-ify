namespace PcIfy.Server.Models;

public class UserCredential
{
    public string Username { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    // Empty = unrestricted (access all source directories).
    public List<string> AllowedDirectories { get; set; } = [];
}
