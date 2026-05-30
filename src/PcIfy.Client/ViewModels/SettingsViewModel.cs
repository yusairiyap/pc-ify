using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PcIfy.Client.Models;
using PcIfy.Client.Services.Interfaces;
using PcIfy.Client.ViewModels.Base;

namespace PcIfy.Client.ViewModels;

public partial class SettingsViewModel : BaseViewModel
{
    private readonly IThemeService _theme;
    private readonly IAuthTokenService _tokenService;
    private readonly IConnectionService _connection;

    [ObservableProperty] private string _selectedTheme = "System";
    [ObservableProperty] private Color _accentColor = Color.FromArgb("#6750A4");
    [ObservableProperty] private GridDensity _gridDensity = GridDensity.Normal;
    [ObservableProperty] private string? _serverAddress;

    public IReadOnlyList<string> ThemeOptions { get; } = ["System", "Light", "Dark"];
    public IReadOnlyList<GridDensity> DensityOptions { get; } = [GridDensity.Compact, GridDensity.Normal, GridDensity.Large];

    public IReadOnlyList<string> PresetColors { get; } =
    [
        "#6750A4", // Material purple (default)
        "#1976D2", // Blue
        "#0097A7", // Teal
        "#388E3C", // Green
        "#F57C00", // Orange
        "#D32F2F", // Red
        "#C2185B", // Pink
        "#455A64", // Blue grey
        "#37474F", // Dark grey
    ];

    public SettingsViewModel(IThemeService theme, IAuthTokenService tokenService, IConnectionService connection)
    {
        _theme = theme;
        _tokenService = tokenService;
        _connection = connection;
        Title = "Settings";
        LoadCurrentValues();
    }

    private void LoadCurrentValues()
    {
        SelectedTheme = _theme.CurrentTheme switch
        {
            AppTheme.Dark  => "Dark",
            AppTheme.Light => "Light",
            _              => "System"
        };
        AccentColor = _theme.CurrentAccent;
        GridDensity = (GridDensity)Enum.Parse(typeof(GridDensity),
            Preferences.Get("grid_density", "Normal"));
        ServerAddress = _connection.BaseUrl;
    }

    [RelayCommand]
    private void SelectAccentColor(string hex)
    {
        AccentColor = Color.FromArgb(hex);
    }

    [RelayCommand]
    private void ApplyTheme()
    {
        var appTheme = SelectedTheme switch
        {
            "Dark"  => AppTheme.Dark,
            "Light" => AppTheme.Light,
            _       => AppTheme.Unspecified
        };
        _theme.Apply(appTheme, AccentColor);
        Preferences.Set("grid_density", GridDensity.ToString());
    }

    [RelayCommand]
    private async Task ChangeServerAsync()
    {
        await Shell.Current.GoToAsync("//setup");
    }

    [RelayCommand]
    private async Task LogoutAsync()
    {
        await _tokenService.ClearTokenAsync();
        await Shell.Current.GoToAsync("//setup");
    }
}
