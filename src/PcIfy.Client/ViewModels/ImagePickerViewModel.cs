using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;
using PcIfy.Client.Messages;
using PcIfy.Client.Services.Interfaces;
using PcIfy.Client.ViewModels.Base;
using PcIfy.Shared.DTOs.Files;

namespace PcIfy.Client.ViewModels;

[QueryProperty(nameof(StartPath), "startPath")]
public partial class ImagePickerViewModel : BaseViewModel
{
    private readonly IApiService _api;
    private readonly IAuthTokenService _tokenService;

    [ObservableProperty] private string? _startPath;
    [ObservableProperty] private string? _currentPath;
    [ObservableProperty] private string? _parentPath;
    [ObservableProperty] private ObservableCollection<BrowserItemViewModel> _items = [];

    public ImagePickerViewModel(IApiService api, IAuthTokenService tokenService)
    {
        _api = api;
        _tokenService = tokenService;
        Title = "Pick Background";
    }

    partial void OnStartPathChanged(string? value)
    {
        if (!string.IsNullOrEmpty(value))
        {
            CurrentPath = value;
            _ = LoadAsync();
        }
    }

    private async Task LoadAsync()
    {
        if (string.IsNullOrEmpty(CurrentPath)) return;
        IsBusy = true;
        try
        {
            var listing = await _api.GetFolderListingAsync(CurrentPath);
            if (listing is null) return;

            Title = listing.DisplayName;
            ParentPath = listing.ParentPath;

            var token = await _tokenService.GetTokenAsync() ?? string.Empty;

            var filtered = listing.Entries
                .Where(e => e.Type == FileType.Folder || e.Type == FileType.Image)
                .OrderBy(e => e.Type == FileType.Folder ? 0 : 1)
                .ThenBy(e => e.Name);

            Items = new ObservableCollection<BrowserItemViewModel>(filtered.Select(e =>
            {
                Uri? thumbUri = null;
                if (e.Type == FileType.Image)
                {
                    var baseThumb = _api.GetThumbnailUri(e.Path).ToString();
                    thumbUri = new Uri(baseThumb + "&token=" + Uri.EscapeDataString(token));
                }
                return new BrowserItemViewModel(e, thumbUri, TapItemAsync);
            }));
        }
        finally { IsBusy = false; }
    }

    private async Task TapItemAsync(BrowserItemViewModel item)
    {
        if (item.Entry.Type == FileType.Folder)
        {
            CurrentPath = item.Entry.Path;
            await LoadAsync();
        }
        else if (item.Entry.Type == FileType.Image)
        {
            WeakReferenceMessenger.Default.Send(new ImagePickedMessage(item.Entry.Path));
            await Shell.Current.GoToAsync("..");
        }
    }

    [RelayCommand]
    private async Task NavigateUpAsync()
    {
        if (!string.IsNullOrEmpty(ParentPath))
        {
            CurrentPath = ParentPath;
            await LoadAsync();
        }
        else
        {
            await Shell.Current.GoToAsync("..");
        }
    }

    [RelayCommand]
    private async Task CancelAsync() => await Shell.Current.GoToAsync("..");
}
