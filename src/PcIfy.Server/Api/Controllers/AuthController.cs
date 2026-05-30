using Microsoft.AspNetCore.Mvc;
using PcIfy.Server.Services.Interfaces;
using PcIfy.Server.Constants;
using PcIfy.Server.DTOs.Auth;

namespace PcIfy.Server.Api.Controllers;

[ApiController]
public class AuthController : ControllerBase
{
    private readonly IAuthService _auth;

    public AuthController(IAuthService auth) => _auth = auth;

    [HttpPost(ApiRoutes.AuthLogin)]
    public IActionResult Login([FromBody] LoginRequest request)
    {
        if (!_auth.ValidateCredentials(request.Username, request.Password))
            return Unauthorized(new { error = "Invalid username or password." });

        var token = _auth.GenerateToken(request.Username);
        return Ok(new LoginResponse
        {
            Token = token,
            ExpiresAt = DateTime.UtcNow.AddHours(24)
        });
    }
}
