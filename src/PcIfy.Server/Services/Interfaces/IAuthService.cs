namespace PcIfy.Server.Services.Interfaces;

public interface IAuthService
{
    bool ValidateCredentials(string username, string password);
    string GenerateToken(string username);
}
