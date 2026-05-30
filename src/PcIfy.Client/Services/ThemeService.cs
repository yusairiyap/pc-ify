using PcIfy.Client.Services.Interfaces;

namespace PcIfy.Client.Services;

public class ThemeService : IThemeService
{
    private const string ThemeKey = "app_theme";
    private const string AccentKey = "app_accent";

    public AppTheme CurrentTheme { get; private set; } = AppTheme.Unspecified;
    public Color CurrentAccent { get; private set; } = Color.FromArgb("#6750A4");

    public void ApplyFromPreferences()
    {
        var themeStr = Preferences.Get(ThemeKey, "System");
        var accentStr = Preferences.Get(AccentKey, "#6750A4");

        var theme = themeStr switch
        {
            "Dark"  => AppTheme.Dark,
            "Light" => AppTheme.Light,
            _       => AppTheme.Unspecified
        };

        Apply(theme, Color.FromArgb(accentStr));
    }

    public void Apply(AppTheme theme, Color accent)
    {
        CurrentTheme = theme;
        CurrentAccent = accent;

        if (Application.Current is not null)
            Application.Current.UserAppTheme = theme;

        ApplyAccentToResources(accent);

        Preferences.Set(ThemeKey, theme switch
        {
            AppTheme.Dark  => "Dark",
            AppTheme.Light => "Light",
            _              => "System"
        });
        Preferences.Set(AccentKey, accent.ToArgbHex());
    }

    private static void ApplyAccentToResources(Color accent)
    {
        if (Application.Current?.Resources is not ResourceDictionary res) return;

        var dark = new Color(accent.Red * 0.7f, accent.Green * 0.7f, accent.Blue * 0.7f);
        var light = new Color(
            Math.Min(1f, accent.Red * 1.3f),
            Math.Min(1f, accent.Green * 1.3f),
            Math.Min(1f, accent.Blue * 1.3f));

        res["Primary"]      = accent;
        res["PrimaryDark"]  = dark;
        res["PrimaryLight"] = light;
        res["PrimaryBrush"] = new SolidColorBrush(accent);
    }
}
