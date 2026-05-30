using CommunityToolkit.Mvvm.Input;
using PcIfy.Shared.DTOs.Files;

namespace PcIfy.Client.ViewModels;

public class BrowserItemViewModel
{
    public FileEntryDto Entry { get; }
    public Uri? ThumbnailUri { get; }
    public bool HasThumbnail => ThumbnailUri is not null;
    public bool IsImage => Entry.Type == FileType.Image;
    public IAsyncRelayCommand OpenCommand { get; }
    public IAsyncRelayCommand LongPressCommand { get; }

    public BrowserItemViewModel(
        FileEntryDto entry,
        Uri? thumbnailUri,
        Func<BrowserItemViewModel, Task>? open = null,
        Func<BrowserItemViewModel, Task>? longPress = null)
    {
        Entry = entry;
        ThumbnailUri = thumbnailUri;
        OpenCommand = new AsyncRelayCommand(() => open?.Invoke(this) ?? Task.CompletedTask);
        LongPressCommand = new AsyncRelayCommand(() => longPress?.Invoke(this) ?? Task.CompletedTask);
    }
}
