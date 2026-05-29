using CommunityToolkit.Mvvm.Messaging;
using PcIfy.Client.Messages;
using PcIfy.Client.Services.Interfaces;

namespace PcIfy.Client;

public partial class App : Application
{
    private readonly IConnectionService _connection;
    private readonly IAuthTokenService _tokenService;
    private readonly IThemeService _theme;

    public App(IConnectionService connection, IAuthTokenService tokenService, IThemeService theme)
    {
        _connection = connection;
        _tokenService = tokenService;
        _theme = theme;

        InitializeComponent();

        _theme.ApplyFromPreferences();

        WeakReferenceMessenger.Default.Register<SessionExpiredMessage>(this, async (_, _) =>
        {
            await MainThread.InvokeOnMainThreadAsync(async () =>
            {
                await Shell.Current.DisplayAlert("Session Expired", "Please log in again.", "OK");
                await Shell.Current.GoToAsync("//setup");
            });
        });
    }

    protected override Window CreateWindow(IActivationState? activationState)
    {
        var window = new Window(new AppShell());
#if WINDOWS
        window.Width = 1200;
        window.Height = 800;
        window.MinimumWidth = 640;
        window.MinimumHeight = 480;
#endif
        return window;
    }

    protected override async void OnStart()
    {
        base.OnStart();
        await NavigateInitialRouteAsync();
    }

    protected override async void OnResume()
    {
        base.OnResume();
        if (!await _tokenService.IsTokenValidAsync())
        {
            await MainThread.InvokeOnMainThreadAsync(async () =>
                await Shell.Current.GoToAsync("//setup"));
        }
    }

    private async Task NavigateInitialRouteAsync()
    {
        await Task.Delay(200); // Let shell initialize
        if (_connection.IsConfigured && await _tokenService.IsTokenValidAsync())
            await Shell.Current.GoToAsync("//home");
        else
            await Shell.Current.GoToAsync("//setup");
    }
}
