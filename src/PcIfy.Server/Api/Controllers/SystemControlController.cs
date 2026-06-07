using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PcIfy.Server.Constants;
using PcIfy.Server.DTOs.System;
using PcIfy.Server.Models;
using PcIfy.Server.Services.Interfaces;

namespace PcIfy.Server.Api.Controllers;

[ApiController]
[Authorize]
public class SystemControlController : ControllerBase
{
    private readonly ISystemControlService _control;
    private readonly AppSettings _settings;
    private readonly ISettingsService _settingsService;

    public SystemControlController(
        ISystemControlService control,
        AppSettings settings,
        ISettingsService settingsService)
    {
        _control = control;
        _settings = settings;
        _settingsService = settingsService;
    }

    [HttpGet(ApiRoutes.SystemControlStatus)]
    public IActionResult GetStatus() => Ok(_control.GetStatus());

    [HttpPost(ApiRoutes.SystemControlVolume)]
    public IActionResult SetVolume([FromBody] SetVolumeRequest req)
    {
        _control.SetVolume(req.Level);
        return Ok();
    }

    [HttpPost(ApiRoutes.SystemControlMute)]
    public IActionResult SetMute([FromBody] SetMuteRequest req)
    {
        _control.SetMute(req.Muted);
        return Ok();
    }

    [HttpPost(ApiRoutes.SystemControlLock)]
    public IActionResult LockScreen()
    {
        _control.LockScreen();
        return Ok();
    }

    [HttpPost(ApiRoutes.SystemControlWake)]
    public IActionResult WakeScreen()
    {
        _control.WakeScreen();
        return Ok();
    }

    [HttpGet(ApiRoutes.SystemControlClipboard)]
    public IActionResult GetClipboard() => Ok(_control.GetClipboard());

    [HttpGet(ApiRoutes.SystemApps)]
    public IActionResult GetApps() => Ok(_control.GetApps(_settings.LauncherApps));

    [HttpPost(ApiRoutes.SystemAppsLaunch)]
    public IActionResult LaunchApp([FromBody] LaunchAppRequest req)
    {
        var app = _settings.LauncherApps.FirstOrDefault(a => a.Id == req.Id);
        if (app is null) return NotFound();
        _control.LaunchApp(app.ExecutablePath);
        return Ok();
    }

    [HttpPost(ApiRoutes.SystemAppsAdd)]
    public IActionResult AddApp([FromBody] AddAppRequest req)
    {
        var newApp = new LauncherApp
        {
            Id = Guid.NewGuid().ToString("N")[..8],
            Name = req.Name,
            ExecutablePath = req.ExecutablePath,
            ProcessName = req.ProcessName,
            IconKey = req.IconKey,
        };
        _settings.LauncherApps.Add(newApp);
        _settingsService.Save(_settings);
        return Ok(newApp);
    }

    [HttpDelete(ApiRoutes.SystemAppsDelete)]
    public IActionResult RemoveApp(string id)
    {
        var removed = _settings.LauncherApps.RemoveAll(a => a.Id == id);
        if (removed == 0) return NotFound();
        _settingsService.Save(_settings);
        return Ok();
    }
}
