namespace PcIfy.Server.Models;

public class ConnectionLogEntry
{
    public DateTime Timestamp { get; set; } = DateTime.Now;
    public string ClientIp { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string Method { get; set; } = string.Empty;
    public string Path { get; set; } = string.Empty;
    public int StatusCode { get; set; }
}
