using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PcIfy.Server.Constants;
using PcIfy.Server.DTOs.System;
using PcIfy.Server.Services.Interfaces;

namespace PcIfy.Server.Api.Controllers;

[ApiController]
[Authorize]
public class SystemControlController : ControllerBase
{
    private readonly ISystemControlService _control;

    public SystemControlController(ISystemControlService control) => _control = control;

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

    [HttpGet(ApiRoutes.SystemControlNotifications)]
    public IActionResult GetNotifications() => Ok(new
    {
        items = _control.GetNotifications(),
        available = false
    });

    [HttpDelete(ApiRoutes.SystemControlNotifications)]
    public IActionResult ClearNotifications()
    {
        _control.ClearNotifications();
        return Ok();
    }
}
