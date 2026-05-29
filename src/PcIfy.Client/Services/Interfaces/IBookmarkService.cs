using PcIfy.Client.Models;

namespace PcIfy.Client.Services.Interfaces;

public interface IBookmarkService
{
    IReadOnlyList<BookmarkedFolder> GetBookmarks();
    void AddBookmark(string path, string displayName, string? coverPath = null);
    void RemoveBookmark(string path);
    event EventHandler BookmarksChanged;
}
