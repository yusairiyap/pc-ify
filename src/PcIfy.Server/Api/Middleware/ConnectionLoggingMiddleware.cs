using Microsoft.AspNetCore.Http;
using PcIfy.Server.Models;
using PcIfy.Server.Services.Interfaces;

namespace PcIfy.Server.Api.Middleware;

public class ConnectionLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IConnectionLogService _logService;

    public ConnectionLoggingMiddleware(RequestDelegate next, IConnectionLogService logService)
    {
        _next = next;
        _logService = logService;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        await _next(context);

        _logService.Log(new ConnectionLogEntry
        {
            Timestamp = DateTime.Now,
            ClientIp = context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            Username = context.User.Identity?.Name ?? "anonymous",
            Method = context.Request.Method,
            Path = context.Request.Path + context.Request.QueryString,
            StatusCode = context.Response.StatusCode
        });
    }
}
