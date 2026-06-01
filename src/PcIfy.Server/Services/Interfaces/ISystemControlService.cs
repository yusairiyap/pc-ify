using PcIfy.Server.DTOs.System;

namespace PcIfy.Server.Services.Interfaces;

public interface ISystemControlService
{
    ControlStatusDto GetStatus();
    void SetVolume(int level);
    void SetMute(bool muted);
    void LockScreen();
    void WakeScreen();
    IReadOnlyList<NotificationItemDto> GetNotifications();
    void ClearNotifications();
}
