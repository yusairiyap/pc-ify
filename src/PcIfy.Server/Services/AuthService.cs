using PcIfy.Server.Helpers;
using PcIfy.Server.Models;
using PcIfy.Server.Services.Interfaces;

namespace PcIfy.Server.Services;

public class AuthService : IAuthService
{
    private readonly AppSettings _settings;

    public AuthService(AppSettings settings) => _settings = settings;

    public bool ValidateCredentials(string username, string password)
    {
        var user = _settings.Users.FirstOrDefault(u =>
            string.Equals(u.Username, username, StringComparison.OrdinalIgnoreCase));

        return user is not null && PasswordHasher.Verify(password, user.PasswordHash);
    }

    public string GenerateToken(string username) =>
        JwtHelper.GenerateToken(username, _settings.JwtSecret, _settings.TokenExpiryHours);
}
