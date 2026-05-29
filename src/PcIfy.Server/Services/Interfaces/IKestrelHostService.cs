namespace PcIfy.Server.Services.Interfaces;

public interface IKestrelHostService
{
    Task StartAsync(int port);
    Task StopAsync();
    bool IsRunning { get; }
    int? CurrentPort { get; }
    event EventHandler<bool> RunningStateChanged;
}
