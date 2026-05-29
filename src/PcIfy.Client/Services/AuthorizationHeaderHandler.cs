using System.Net.Http.Headers;
using CommunityToolkit.Mvvm.Messaging;
using PcIfy.Client.Messages;
using PcIfy.Client.Services.Interfaces;

namespace PcIfy.Client.Services;

public class AuthorizationHeaderHandler : DelegatingHandler
{
    private readonly IAuthTokenService _tokenService;

    public AuthorizationHeaderHandler(IAuthTokenService tokenService)
    {
        _tokenService = tokenService;
    }

    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
    {
        var token = await _tokenService.GetTokenAsync();
        if (!string.IsNullOrEmpty(token))
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await base.SendAsync(request, ct);

        if (response.StatusCode == System.Net.HttpStatusCode.Unauthorized)
        {
            await _tokenService.ClearTokenAsync();
            WeakReferenceMessenger.Default.Send(new SessionExpiredMessage());
        }

        return response;
    }
}
