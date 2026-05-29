using Microsoft.AspNetCore.Mvc;
using PcIfy.Server.Models;
using PcIfy.Shared.Constants;
using PcIfy.Shared.DTOs.System;

namespace PcIfy.Server.Api.Controllers;

[ApiController]
public class SystemController : ControllerBase
{
    private readonly AppSettings _settings;

    public SystemController(AppSettings settings) => _settings = settings;

    [HttpGet(ApiRoutes.SystemHealth)]
    public IActionResult Health() => Ok(new { status = "ok" });

    [HttpGet(ApiRoutes.SystemInfo)]
    public IActionResult Info() => Ok(new ServerInfoDto
    {
        ServerName = _settings.ServerName,
        Version = "1.0.0",
        OsVersion = Environment.OSVersion.ToString()
    });
}
