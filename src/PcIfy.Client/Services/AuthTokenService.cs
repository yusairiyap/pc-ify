using System.IdentityModel.Tokens.Jwt;
using PcIfy.Client.Services.Interfaces;

namespace PcIfy.Client.Services;

public class AuthTokenService : IAuthTokenService
{
    private const string TokenKey = "auth_token";

    public Task SaveTokenAsync(string token) =>
        SecureStorage.SetAsync(TokenKey, token);

    public Task<string?> GetTokenAsync() =>
        SecureStorage.GetAsync(TokenKey);

    public Task ClearTokenAsync()
    {
        SecureStorage.Remove(TokenKey);
        return Task.CompletedTask;
    }

    public async Task<bool> IsTokenValidAsync()
    {
        var token = await GetTokenAsync();
        if (string.IsNullOrEmpty(token)) return false;

        try
        {
            var handler = new JwtSecurityTokenHandler();
            var jwt = handler.ReadJwtToken(token);
            return jwt.ValidTo > DateTime.UtcNow.AddMinutes(5);
        }
        catch
        {
            return false;
        }
    }
}
