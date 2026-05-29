namespace PcIfy.Client.Services.Interfaces;

public interface IThemeService
{
    void Apply(AppTheme theme, Color accent);
    void ApplyFromPreferences();
    AppTheme CurrentTheme { get; }
    Color CurrentAccent { get; }
}
