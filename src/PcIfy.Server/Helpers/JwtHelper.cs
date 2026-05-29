using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

namespace PcIfy.Server.Helpers;

public static class JwtHelper
{
    private static readonly string[] StreamingPathPrefixes = ["/api/files/stream", "/api/files/download", "/api/thumbnails"];

    public static string GenerateToken(string username, string secret, int expiryHours)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: "pcify-server",
            audience: "pcify-client",
            claims: [new Claim(ClaimTypes.Name, username), new Claim(JwtRegisteredClaimNames.Sub, username)],
            expires: DateTime.UtcNow.AddHours(expiryHours),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public static TokenValidationParameters GetValidationParameters(string secret) => new()
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret)),
        ValidateIssuer = true,
        ValidIssuer = "pcify-server",
        ValidateAudience = true,
        ValidAudience = "pcify-client",
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero
    };

    public static void ConfigureJwtBearerOptions(JwtBearerOptions options, string secret)
    {
        options.TokenValidationParameters = GetValidationParameters(secret);

        // Allow token via query param for streaming/thumbnail endpoints (MediaElement cannot set headers)
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var path = context.HttpContext.Request.Path.Value ?? string.Empty;
                if (StreamingPathPrefixes.Any(prefix => path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)))
                {
                    var token = context.HttpContext.Request.Query["token"];
                    if (!string.IsNullOrEmpty(token))
                        context.Token = token;
                }
                return Task.CompletedTask;
            }
        };
    }
}
