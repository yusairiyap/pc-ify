using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PcIfy.Client.Services.Interfaces;
using PcIfy.Client.ViewModels.Base;
using PcIfy.Shared.Constants;

namespace PcIfy.Client.ViewModels;

[QueryProperty(nameof(FilePath), "path")]
[QueryProperty(nameof(FileName), "name")]
public partial class VideoPlayerViewModel : BaseViewModel
{
    private readonly IApiService _api;
    private readonly IAuthTokenService _tokenService;
    private readonly IExternalPlayerService _externalPlayer;

    [ObservableProperty] private string? _filePath;
    [ObservableProperty] private string? _fileName;
    [ObservableProperty] private Uri? _streamUri;

    public VideoPlayerViewModel(IApiService api, IAuthTokenService tokenService, IExternalPlayerService externalPlayer)
    {
        _api = api;
        _tokenService = tokenService;
        _externalPlayer = externalPlayer;
        Title = "Now Playing";
    }

    partial void OnFilePathChanged(string? value)
    {
        if (!string.IsNullOrEmpty(value))
            _ = BuildStreamUriAsync(value);
    }

    private async Task BuildStreamUriAsync(string path)
    {
        var token = await _tokenService.GetTokenAsync() ?? string.Empty;
        var encoded = Uri.EscapeDataString(path.TrimStart('/', '\\').Replace('\\', '/'));
        var base_ = _api.GetStreamUri(path).GetLeftPart(UriPartial.Path);
        StreamUri = new Uri($"{base_}?{ApiRoutes.TokenQueryParam}={Uri.EscapeDataString(token)}");
        Title = FileName ?? "Now Playing";
    }

    [RelayCommand]
    private async Task OpenExternalAsync()
    {
        if (StreamUri is null) return;
        var mimeType = "video/mp4";
        if (await _externalPlayer.CanOpenExternallyAsync(mimeType))
            await _externalPlayer.OpenAsync(StreamUri, mimeType, FileName ?? "Video");
        else
            await Shell.Current.DisplayAlert("Not Supported", "No external player found.", "OK");
    }
}
