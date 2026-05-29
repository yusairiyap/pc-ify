using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PcIfy.Client.Models;
using PcIfy.Client.Services.Interfaces;
using PcIfy.Client.ViewModels.Base;
using PcIfy.Shared.DTOs.Files;

namespace PcIfy.Client.ViewModels;

[QueryProperty(nameof(CurrentPath), "path")]
public partial class BrowserViewModel : BaseViewModel
{
    private readonly IApiService _api;
    private readonly IBookmarkService _bookmarks;
    private readonly IFolderPrefsService _folderPrefs;
    private readonly IDownloadService _downloads;

    [ObservableProperty] private string? _currentPath;
    [ObservableProperty] private ObservableCollection<FileEntryDto> _entries = [];
    [ObservableProperty] private FolderPrefs _folderPrefs_ = new();
    [ObservableProperty] private bool _isTabletLayout;
    [ObservableProperty] private FileEntryDto? _selectedEntry;
    [ObservableProperty] private int _gridColumns = 3;
    [ObservableProperty] private GridDensity _density = GridDensity.Normal;
    [ObservableProperty] private bool _isBookmarked;
    [ObservableProperty] private string? _parentPath;

    public BrowserViewModel(IApiService api, IBookmarkService bookmarks, IFolderPrefsService folderPrefs, IDownloadService downloads)
    {
        _api = api;
        _bookmarks = bookmarks;
        _folderPrefs = folderPrefs;
        _downloads = downloads;
        Title = "Browse";
    }

    partial void OnCurrentPathChanged(string? value)
    {
        if (!string.IsNullOrEmpty(value))
            _ = LoadAsync();
    }

    public async Task LoadAsync()
    {
        if (string.IsNullOrEmpty(CurrentPath)) return;
        IsBusy = true;
        ErrorMessage = null;

        try
        {
            var listing = await _api.GetFolderListingAsync(CurrentPath);
            if (listing is null)
            {
                ErrorMessage = "Failed to load folder.";
                return;
            }

            Title = listing.DisplayName;
            ParentPath = listing.ParentPath;
            Entries = new ObservableCollection<FileEntryDto>(listing.Entries);
            FolderPrefs_ = _folderPrefs.GetPrefs(CurrentPath);
            IsBookmarked = _bookmarks.GetBookmarks().Any(b => b.Path == CurrentPath);
        }
        finally { IsBusy = false; }
    }

    public async Task LoadRootsAsync()
    {
        IsBusy = true;
        try
        {
            var roots = (await _api.GetRootsAsync()).ToList();
            if (roots.Count == 1)
            {
                CurrentPath = roots[0];
            }
            else
            {
                // Multiple roots — show as virtual top-level listing
                Entries = new ObservableCollection<FileEntryDto>(
                    roots.Select(r => new FileEntryDto { Name = Path.GetFileName(r) ?? r, Path = r, Type = FileType.Folder }));
                Title = "Browse";
            }
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task OpenEntryAsync(FileEntryDto entry)
    {
        if (entry.Type == FileType.Folder)
        {
            var encoded = Uri.EscapeDataString(entry.Path);
            await Shell.Current.GoToAsync($"browser?path={encoded}");
            return;
        }

        if (entry.Type == FileType.Video)
        {
            var encoded = Uri.EscapeDataString(entry.Path);
            await Shell.Current.GoToAsync($"videoplayer?path={encoded}&name={Uri.EscapeDataString(entry.Name)}");
            return;
        }

        if (entry.Type == FileType.Image)
        {
            var folderEncoded = Uri.EscapeDataString(CurrentPath ?? string.Empty);
            var index = Entries.Where(e => e.Type == FileType.Image).ToList().IndexOf(entry);
            await Shell.Current.GoToAsync($"imagegallery?path={folderEncoded}&index={index}");
            return;
        }
    }

    [RelayCommand]
    private async Task DownloadAsync(FileEntryDto entry)
    {
        IsBusy = true;
        try
        {
            await _downloads.DownloadFileAsync(entry.Path, entry.Name,
                new Progress<double>(), CancellationToken.None);
            await Shell.Current.DisplayAlert("Downloaded", $"{entry.Name} saved to downloads.", "OK");
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Download failed: {ex.Message}";
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private void ToggleBookmark()
    {
        if (string.IsNullOrEmpty(CurrentPath)) return;
        if (IsBookmarked)
        {
            _bookmarks.RemoveBookmark(CurrentPath);
            IsBookmarked = false;
        }
        else
        {
            _bookmarks.AddBookmark(CurrentPath, Title ?? Path.GetFileName(CurrentPath) ?? CurrentPath);
            IsBookmarked = true;
        }
    }

    [RelayCommand]
    private async Task NavigateUpAsync()
    {
        if (!string.IsNullOrEmpty(ParentPath))
            await Shell.Current.GoToAsync($"browser?path={Uri.EscapeDataString(ParentPath)}");
        else
            await Shell.Current.GoToAsync("..");
    }

    public void UpdateLayout(double width)
    {
        IsTabletLayout = width >= 600;
        GridColumns = Helpers.GridDensityHelper.GetColumnCount(width, Density);
    }

    public void SaveFolderBackground(string filePath, float cx, float cy, float cw, float ch, float zoom)
    {
        if (string.IsNullOrEmpty(CurrentPath)) return;
        var prefs = new FolderPrefs { BackgroundFilePath = filePath, CropX = cx, CropY = cy, CropWidth = cw, CropHeight = ch, ZoomLevel = zoom };
        _folderPrefs.SavePrefs(CurrentPath, prefs);
        FolderPrefs_ = prefs;
    }
}
