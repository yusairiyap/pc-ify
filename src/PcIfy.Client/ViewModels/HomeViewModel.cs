using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;
using PcIfy.Client.Messages;
using PcIfy.Client.Models;
using PcIfy.Client.Services.Interfaces;
using PcIfy.Client.ViewModels.Base;

namespace PcIfy.Client.ViewModels;

public partial class HomeViewModel : BaseViewModel, IRecipient<BookmarksChangedMessage>
{
    private readonly IBookmarkService _bookmarks;
    private readonly IApiService _api;

    [ObservableProperty] private ObservableCollection<BookmarkedFolder> _bookmarkedFolders = [];
    [ObservableProperty] private bool _hasNoBookmarks;

    public HomeViewModel(IBookmarkService bookmarks, IApiService api)
    {
        _bookmarks = bookmarks;
        _api = api;
        Title = "Home";
        bookmarks.BookmarksChanged += (_, _) => LoadBookmarks();
        WeakReferenceMessenger.Default.Register(this);
    }

    public void Receive(BookmarksChangedMessage message) => LoadBookmarks();

    public void LoadBookmarks()
    {
        BookmarkedFolders = new ObservableCollection<BookmarkedFolder>(_bookmarks.GetBookmarks());
        HasNoBookmarks = BookmarkedFolders.Count == 0;
    }

    [RelayCommand]
    private async Task OpenFolderAsync(BookmarkedFolder folder)
    {
        var encoded = Uri.EscapeDataString(folder.Path);
        await Shell.Current.GoToAsync($"browser?path={encoded}");
    }

    [RelayCommand]
    private void RemoveBookmark(BookmarkedFolder folder)
    {
        _bookmarks.RemoveBookmark(folder.Path);
        LoadBookmarks();
    }

    [RelayCommand]
    private async Task BrowseAllAsync()
    {
        await Shell.Current.GoToAsync("//browse_root");
    }
}
