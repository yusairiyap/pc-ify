using PcIfy.Client.Models;

namespace PcIfy.Client.Services.Interfaces;

public interface IFolderPrefsService
{
    FolderPrefs GetPrefs(string folderPath);
    void SavePrefs(string folderPath, FolderPrefs prefs);
}
