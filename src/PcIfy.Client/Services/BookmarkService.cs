using System.Text.Json;
using PcIfy.Client.Models;
using PcIfy.Client.Services.Interfaces;

namespace PcIfy.Client.Services;

public class BookmarkService : IBookmarkService
{
    private const string PrefsKey = "bookmarks_json";
    private List<BookmarkedFolder> _bookmarks;

    public event EventHandler? BookmarksChanged;

    public BookmarkService()
    {
        var json = Preferences.Get(PrefsKey, null);
        _bookmarks = json is null ? [] : JsonSerializer.Deserialize<List<BookmarkedFolder>>(json) ?? [];
    }

    public IReadOnlyList<BookmarkedFolder> GetBookmarks() => _bookmarks.AsReadOnly();

    public void AddBookmark(string path, string displayName, string? coverPath = null)
    {
        _bookmarks.RemoveAll(b => b.Path == path);
        _bookmarks.Add(new BookmarkedFolder { Path = path, DisplayName = displayName, CoverThumbnailServerPath = coverPath });
        Persist();
    }

    public void RemoveBookmark(string path)
    {
        _bookmarks.RemoveAll(b => b.Path == path);
        Persist();
    }

    private void Persist()
    {
        Preferences.Set(PrefsKey, JsonSerializer.Serialize(_bookmarks));
        BookmarksChanged?.Invoke(this, EventArgs.Empty);
    }
}
