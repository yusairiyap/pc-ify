using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PcIfy.Client.Services.Interfaces;
using PcIfy.Client.ViewModels.Base;
using PcIfy.Shared.Constants;
using PcIfy.Shared.DTOs.Files;

namespace PcIfy.Client.ViewModels;

[QueryProperty(nameof(FolderPath), "path")]
[QueryProperty(nameof(StartIndexStr), "index")]
public partial class ImageGalleryViewModel : BaseViewModel
{
    private readonly IApiService _api;
    private readonly IAuthTokenService _tokenService;

    [ObservableProperty] private string? _folderPath;
    [ObservableProperty] private string? _startIndexStr;
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CurrentImageName))]
    private ObservableCollection<ImageItemViewModel> _images = [];
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CurrentImageName))]
    private int _currentIndex;

    private int _pendingStartIndex;

    public string CurrentImageName => CurrentIndex >= 0 && CurrentIndex < Images.Count
        ? Images[CurrentIndex].Name : string.Empty;

    public ImageGalleryViewModel(IApiService api, IAuthTokenService tokenService)
    {
        _api = api;
        _tokenService = tokenService;
        Title = "Gallery";
    }

    partial void OnFolderPathChanged(string? value)
    {
        if (!string.IsNullOrEmpty(value))
            _ = LoadImagesAsync();
    }

    partial void OnStartIndexStrChanged(string? value)
    {
        if (int.TryParse(value, out var idx))
            _pendingStartIndex = idx;
    }

    private async Task LoadImagesAsync()
    {
        if (string.IsNullOrEmpty(FolderPath)) return;
        IsBusy = true;
        try
        {
            var listing = await _api.GetFolderListingAsync(FolderPath);
            if (listing is null) return;

            var token = await _tokenService.GetTokenAsync() ?? string.Empty;
            var imageEntries = listing.Entries.Where(e => e.Type == FileType.Image).ToList();

            Images = new ObservableCollection<ImageItemViewModel>(
                imageEntries.Select(e =>
                {
                    var baseUri = _api.GetStreamUri(e.Path).ToString();
                    var streamUri = new Uri($"{baseUri}?{ApiRoutes.TokenQueryParam}={Uri.EscapeDataString(token)}");
                    return new ImageItemViewModel(e.Name, e.Path, streamUri);
                }));

            // Apply the start index after Images is populated — CarouselView ignores
            // Position set before its ItemsSource is ready and resets to 0.
            CurrentIndex = _pendingStartIndex;
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private void GoPrevious()
    {
        if (CurrentIndex > 0) CurrentIndex--;
    }

    [RelayCommand]
    private void GoNext()
    {
        if (CurrentIndex < Images.Count - 1) CurrentIndex++;
    }
}
