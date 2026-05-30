using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;
using PcIfy.Client.Messages;
using PcIfy.Client.Models;
using PcIfy.Client.Services.Interfaces;
using PcIfy.Client.ViewModels.Base;
using PcIfy.Shared.Constants;
using PcIfy.Shared.DTOs.Files;

namespace PcIfy.Client.ViewModels;

[QueryProperty(nameof(CurrentPath), "path")]
public partial class BrowserViewModel : BaseViewModel
{
    private readonly IApiService _api;
    private readonly IBookmarkService _bookmarks;
    private readonly IFolderPrefsService _folderPrefs;
    private readonly IDownloadService _downloads;
    private readonly IAuthTokenService _tokenService;
    private readonly IExternalPlayerService _externalPlayer;

    [ObservableProperty] private string? _currentPath;
    [ObservableProperty] private ObservableCollection<FileEntryDto> _entries = [];
    [ObservableProperty] private ObservableCollection<BrowserItemViewModel> _items = [];
    [ObservableProperty] private FolderPrefs _folderPrefs_ = new();
    [ObservableProperty] private bool _isTabletLayout;

    private ImageSource? _backgroundImageSource;
    public ImageSource? BackgroundImageSource
    {
        get => _backgroundImageSource;
        set => SetProperty(ref _backgroundImageSource, value);
    }
    [ObservableProperty] private FileEntryDto? _selectedEntry;
    [ObservableProperty] private int _gridColumns = 3;
    [ObservableProperty] private GridDensity _density = GridDensity.Normal;
    [ObservableProperty] private bool _isBookmarked;
    [ObservableProperty] private string? _parentPath;

    public BrowserViewModel(IApiService api, IBookmarkService bookmarks, IFolderPrefsService folderPrefs,
        IDownloadService downloads, IAuthTokenService tokenService, IExternalPlayerService externalPlayer)
    {
        _api = api;
        _bookmarks = bookmarks;
        _folderPrefs = folderPrefs;
        _downloads = downloads;
        _tokenService = tokenService;
        _externalPlayer = externalPlayer;
        Title = "Browse";

        Density = (GridDensity)Enum.Parse(typeof(GridDensity), Preferences.Get("grid_density", "Normal"));
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

            await BuildItemsAsync(listing.Entries);
            await RefreshBackgroundSourceAsync();
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
                var rootEntries = roots
                    .Select(r => new FileEntryDto { Name = Path.GetFileName(r) ?? r, Path = r, Type = FileType.Folder })
                    .ToList();
                Entries = new ObservableCollection<FileEntryDto>(rootEntries);
                Title = "Browse";
                await BuildItemsAsync(rootEntries);
            }
        }
        finally { IsBusy = false; }
    }

    private async Task BuildItemsAsync(IEnumerable<FileEntryDto> entries)
    {
        var token = await _tokenService.GetTokenAsync() ?? string.Empty;

        Items = new ObservableCollection<BrowserItemViewModel>(entries.Select(e =>
        {
            Uri? thumbUri = null;
            if (e.Type == FileType.Image || e.Type == FileType.Video)
            {
                var baseThumb = _api.GetThumbnailUri(e.Path).ToString();
                thumbUri = new Uri(baseThumb + "&token=" + Uri.EscapeDataString(token));
            }
            return new BrowserItemViewModel(e, thumbUri, ProcessEntryItemAsync, LongPressItemAsync);
        }));
    }

    private async Task RefreshBackgroundSourceAsync()
    {
        if (string.IsNullOrEmpty(FolderPrefs_.BackgroundFilePath))
        {
            BackgroundImageSource = null;
            return;
        }

        var token = await _tokenService.GetTokenAsync() ?? string.Empty;
        var baseUri = _api.GetStreamUri(FolderPrefs_.BackgroundFilePath).ToString();
        BackgroundImageSource = new UriImageSource
        {
            Uri = new Uri($"{baseUri}?{ApiRoutes.TokenQueryParam}={Uri.EscapeDataString(token)}"),
            CachingEnabled = false
        };
    }

    private Task ProcessEntryItemAsync(BrowserItemViewModel item) => ProcessEntryAsync(item.Entry);

    private async Task LongPressItemAsync(BrowserItemViewModel item)
    {
        switch (item.Entry.Type)
        {
            case FileType.Folder:
                await HandleFolderLongPressAsync(item.Entry);
                break;
            case FileType.Video:
                await HandleVideoLongPressAsync(item.Entry);
                break;
            case FileType.Image:
                await HandleImageLongPressAsync(item.Entry);
                break;
            default:
                await OpenOrDownloadAsync(item.Entry);
                break;
        }
    }

    private async Task HandleFolderLongPressAsync(FileEntryDto entry)
    {
        var isBookmarked = _bookmarks.GetBookmarks().Any(b => b.Path == entry.Path);
        var bookmarkLabel = isBookmarked ? "Remove Bookmark" : "Bookmark";
        var action = await Shell.Current.DisplayActionSheetAsync(entry.Name, "Cancel", null, "Open", bookmarkLabel);

        if (action == "Open")
            await Shell.Current.GoToAsync($"browser?path={Uri.EscapeDataString(entry.Path)}");
        else if (action == bookmarkLabel)
        {
            if (isBookmarked) _bookmarks.RemoveBookmark(entry.Path);
            else _bookmarks.AddBookmark(entry.Path, entry.Name);
        }
    }

    private async Task HandleVideoLongPressAsync(FileEntryDto entry)
    {
        var action = await Shell.Current.DisplayActionSheetAsync(
            entry.Name, "Cancel", null, "Play in app", "Open with external player", "Download");

        if (action == "Play in app")
            await Shell.Current.GoToAsync(
                $"videoplayer?path={Uri.EscapeDataString(entry.Path)}&name={Uri.EscapeDataString(entry.Name)}");
        else if (action == "Open with external player")
            await OpenVideoExternallyAsync(entry);
        else if (action == "Download")
            await DownloadFileAsync(entry);
    }

    private async Task HandleImageLongPressAsync(FileEntryDto entry)
    {
        var action = await Shell.Current.DisplayActionSheetAsync(
            entry.Name, "Cancel", null, "View", "Open with external app", "Download");

        if (action == "View")
        {
            var folderEncoded = Uri.EscapeDataString(CurrentPath ?? string.Empty);
            var index = Entries.Where(e => e.Type == FileType.Image).ToList().IndexOf(entry);
            await Shell.Current.GoToAsync($"imagegallery?path={folderEncoded}&index={index}");
        }
        else if (action == "Open with external app")
            await OpenWithExternalAppAsync(entry);
        else if (action == "Download")
            await DownloadFileAsync(entry);
    }

    private async Task OpenVideoExternallyAsync(FileEntryDto entry)
    {
        IsBusy = true;
        try
        {
            var token = await _tokenService.GetTokenAsync() ?? string.Empty;
            var baseUri = _api.GetStreamUri(entry.Path).ToString();
            var streamUri = new Uri($"{baseUri}?{ApiRoutes.TokenQueryParam}={Uri.EscapeDataString(token)}");
            await _externalPlayer.OpenAsync(streamUri, GetMimeType(entry), entry.Name);
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlertAsync("Error", $"Could not open externally: {ex.Message}", "OK");
        }
        finally { IsBusy = false; }
    }

    private static string GetMimeType(FileEntryDto entry) => entry.Type switch
    {
        FileType.Video => GetVideoMimeType(entry.Name),
        FileType.Audio => "audio/*",
        FileType.Image => "image/*",
        _ => "application/octet-stream"
    };

    private static string GetVideoMimeType(string name) =>
        Path.GetExtension(name).ToLowerInvariant() switch
        {
            ".mkv" => "video/x-matroska",
            ".avi" => "video/x-msvideo",
            ".mov" => "video/quicktime",
            ".wmv" => "video/x-ms-wmv",
            _ => "video/mp4"
        };

    private async Task ProcessEntryAsync(FileEntryDto entry)
    {
        if (entry.Type == FileType.Folder)
        {
            await Shell.Current.GoToAsync($"browser?path={Uri.EscapeDataString(entry.Path)}");
            return;
        }

        if (entry.Type == FileType.Video)
        {
            await Shell.Current.GoToAsync(
                $"videoplayer?path={Uri.EscapeDataString(entry.Path)}&name={Uri.EscapeDataString(entry.Name)}");
            return;
        }

        if (entry.Type == FileType.Image)
        {
            var folderEncoded = Uri.EscapeDataString(CurrentPath ?? string.Empty);
            var index = Entries.Where(e => e.Type == FileType.Image).ToList().IndexOf(entry);
            await Shell.Current.GoToAsync($"imagegallery?path={folderEncoded}&index={index}");
            return;
        }

        await OpenOrDownloadAsync(entry);
    }

    private async Task OpenOrDownloadAsync(FileEntryDto entry)
    {
        var action = await Shell.Current.DisplayActionSheetAsync(
            entry.Name, "Cancel", null, "Open with app", "Download");

        if (action == "Open with app")
            await OpenWithExternalAppAsync(entry);
        else if (action == "Download")
            await DownloadFileAsync(entry);
    }

    private async Task OpenWithExternalAppAsync(FileEntryDto entry)
    {
        IsBusy = true;
        try
        {
            var cachePath = Path.Combine(FileSystem.CacheDirectory, entry.Name);
            var stream = await _api.StreamFileAsync(entry.Path);
            if (stream is null)
            {
                await Shell.Current.DisplayAlertAsync("Error", "Could not download file.", "OK");
                return;
            }
            await using (var fs = File.Create(cachePath))
                await stream.CopyToAsync(fs);

            await Launcher.OpenAsync(new OpenFileRequest
            {
                File = new ReadOnlyFile(cachePath),
                Title = entry.Name
            });
        }
        catch (Exception ex)
        {
            await Shell.Current.DisplayAlertAsync("Error", $"Could not open file: {ex.Message}", "OK");
        }
        finally { IsBusy = false; }
    }

    private async Task DownloadFileAsync(FileEntryDto entry)
    {
        IsBusy = true;
        try
        {
            await _downloads.DownloadFileAsync(entry.Path, entry.Name,
                new Progress<double>(), CancellationToken.None);
            await Shell.Current.DisplayAlertAsync("Downloaded", $"{entry.Name} saved to downloads.", "OK");
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

    [RelayCommand]
    private void CycleDensity()
    {
        Density = Density switch
        {
            GridDensity.Compact => GridDensity.Normal,
            GridDensity.Normal  => GridDensity.Large,
            _                   => GridDensity.Compact
        };
        Preferences.Set("grid_density", Density.ToString());
        GridColumns = Helpers.GridDensityHelper.GetColumnCount(
            DeviceDisplay.MainDisplayInfo.Width / DeviceDisplay.MainDisplayInfo.Density, Density);
    }

    [RelayCommand]
    private async Task SetFolderBackgroundAsync()
    {
        if (string.IsNullOrEmpty(CurrentPath)) return;

        // Register for the picker result before navigating
        WeakReferenceMessenger.Default.Unregister<ImagePickedMessage>(this);
        WeakReferenceMessenger.Default.Register<ImagePickedMessage>(this, async (_, msg) =>
        {
            WeakReferenceMessenger.Default.Unregister<ImagePickedMessage>(this);
            SaveFolderBackground(msg.ServerFilePath, 0, 0, 1, 1, 1);
            await RefreshBackgroundSourceAsync();
        });

        await Shell.Current.GoToAsync(
            $"imagepicker?startPath={Uri.EscapeDataString(CurrentPath)}");
    }

    [RelayCommand]
    private async Task ClearFolderBackgroundAsync()
    {
        if (string.IsNullOrEmpty(CurrentPath)) return;
        _folderPrefs.SavePrefs(CurrentPath, new FolderPrefs());
        FolderPrefs_ = new FolderPrefs();
        BackgroundImageSource = null;
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
