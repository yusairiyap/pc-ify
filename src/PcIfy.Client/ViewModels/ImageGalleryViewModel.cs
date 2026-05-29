using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PcIfy.Client.Services.Interfaces;
using PcIfy.Client.ViewModels.Base;
using PcIfy.Shared.DTOs.Files;

namespace PcIfy.Client.ViewModels;

[QueryProperty(nameof(FolderPath), "path")]
[QueryProperty(nameof(StartIndexStr), "index")]
public partial class ImageGalleryViewModel : BaseViewModel
{
    private readonly IApiService _api;

    [ObservableProperty] private string? _folderPath;
    [ObservableProperty] private string? _startIndexStr;
    [ObservableProperty] private ObservableCollection<FileEntryDto> _images = [];
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CurrentImageName))]
    private int _currentIndex;

    public string CurrentImageName => CurrentIndex >= 0 && CurrentIndex < Images.Count
        ? Images[CurrentIndex].Name : string.Empty;

    public ImageGalleryViewModel(IApiService api)
    {
        _api = api;
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
            CurrentIndex = idx;
    }

    private async Task LoadImagesAsync()
    {
        if (string.IsNullOrEmpty(FolderPath)) return;
        IsBusy = true;
        try
        {
            var listing = await _api.GetFolderListingAsync(FolderPath);
            if (listing is null) return;
            Images = new ObservableCollection<FileEntryDto>(
                listing.Entries.Where(e => e.Type == FileType.Image));
        }
        finally { IsBusy = false; }
    }

    public Uri GetImageUri(FileEntryDto entry) =>
        _api.GetStreamUri(entry.Path);

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
