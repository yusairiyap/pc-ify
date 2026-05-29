namespace PcIfy.Client.Services.Interfaces;

public interface IAuthTokenService
{
    Task SaveTokenAsync(string token);
    Task<string?> GetTokenAsync();
    Task ClearTokenAsync();
    Task<bool> IsTokenValidAsync();
}
