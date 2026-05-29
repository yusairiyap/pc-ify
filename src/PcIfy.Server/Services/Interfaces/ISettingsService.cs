using PcIfy.Server.Models;

namespace PcIfy.Server.Services.Interfaces;

public interface ISettingsService
{
    AppSettings Load();
    void Save(AppSettings settings);
    string SettingsFilePath { get; }
}
