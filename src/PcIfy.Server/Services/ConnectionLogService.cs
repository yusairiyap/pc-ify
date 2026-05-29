using System.Collections.Concurrent;
using PcIfy.Server.Models;
using PcIfy.Server.Services.Interfaces;

namespace PcIfy.Server.Services;

public class ConnectionLogService : IConnectionLogService
{
    private readonly ConcurrentQueue<ConnectionLogEntry> _queue = new();
    private const int MaxEntries = 1000;

    public event EventHandler<ConnectionLogEntry>? NewEntry;

    public void Log(ConnectionLogEntry entry)
    {
        _queue.Enqueue(entry);
        while (_queue.Count > MaxEntries)
            _queue.TryDequeue(out _);

        NewEntry?.Invoke(this, entry);
    }

    public IReadOnlyList<ConnectionLogEntry> GetRecent(int count = 200)
    {
        return _queue.TakeLast(count).Reverse().ToList();
    }
}
