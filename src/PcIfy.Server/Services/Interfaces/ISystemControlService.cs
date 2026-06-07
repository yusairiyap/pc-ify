using PcIfy.Server.DTOs.System;
using PcIfy.Server.Models;

namespace PcIfy.Server.Services.Interfaces;

public interface ISystemControlService
{
    ControlStatusDto GetStatus();
    void SetVolume(int level);
    void SetMute(bool muted);
    void LockScreen();
    void WakeScreen();
    ClipboardStatusDto GetClipboard();
    AppLauncherStatusDto GetApps(List<LauncherApp> apps);
    void LaunchApp(string executablePath);
}
