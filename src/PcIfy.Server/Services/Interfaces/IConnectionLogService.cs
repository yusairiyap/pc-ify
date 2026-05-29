using PcIfy.Server.Models;

namespace PcIfy.Server.Services.Interfaces;

public interface IConnectionLogService
{
    void Log(ConnectionLogEntry entry);
    IReadOnlyList<ConnectionLogEntry> GetRecent(int count = 200);
    event EventHandler<ConnectionLogEntry> NewEntry;
}
