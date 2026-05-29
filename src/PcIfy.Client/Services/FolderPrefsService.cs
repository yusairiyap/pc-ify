using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using PcIfy.Client.Models;
using PcIfy.Client.Services.Interfaces;

namespace PcIfy.Client.Services;

public class FolderPrefsService : IFolderPrefsService
{
    private readonly string _baseDir = Path.Combine(FileSystem.AppDataDirectory, "folderprefs");

    public FolderPrefsService() => Directory.CreateDirectory(_baseDir);

    public FolderPrefs GetPrefs(string folderPath)
    {
        var file = GetFilePath(folderPath);
        if (!File.Exists(file)) return new FolderPrefs();
        try { return JsonSerializer.Deserialize<FolderPrefs>(File.ReadAllText(file)) ?? new FolderPrefs(); }
        catch { return new FolderPrefs(); }
    }

    public void SavePrefs(string folderPath, FolderPrefs prefs) =>
        File.WriteAllText(GetFilePath(folderPath), JsonSerializer.Serialize(prefs));

    private string GetFilePath(string folderPath)
    {
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(folderPath)));
        return Path.Combine(_baseDir, hash + ".json");
    }
}
