using CommunityToolkit.Maui;
using CommunityToolkit.Maui.Core;
using Microsoft.Extensions.Logging;
using PcIfy.Client.Services;
using PcIfy.Client.Services.Interfaces;
using PcIfy.Client.ViewModels;
using PcIfy.Client.Views.Browser;
using PcIfy.Client.Views.Home;
using PcIfy.Client.Views.Settings;
using PcIfy.Client.Views.Setup;
using PcIfy.Client.Views.Viewer;

namespace PcIfy.Client;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();

        builder
            .UseMauiApp<App>()
            .UseMauiCommunityToolkit()
            .UseMauiCommunityToolkitMediaElement(false)
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
                fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");
            });

        // HttpClient + auth handler
        builder.Services.AddSingleton<IAuthTokenService, AuthTokenService>();
        builder.Services.AddTransient<AuthorizationHeaderHandler>();
        builder.Services.AddSingleton<HttpClient>(sp =>
        {
            var handler = sp.GetRequiredService<AuthorizationHeaderHandler>();
            handler.InnerHandler = new HttpClientHandler();
            return new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(30) };
        });

        // Services
        builder.Services.AddSingleton<IConnectionService, ConnectionService>();
        builder.Services.AddSingleton<IApiService, ApiService>();
        builder.Services.AddSingleton<IDownloadService, DownloadService>();
        builder.Services.AddSingleton<IBookmarkService, BookmarkService>();
        builder.Services.AddSingleton<IFolderPrefsService, FolderPrefsService>();
        builder.Services.AddSingleton<IThemeService, ThemeService>();
        builder.Services.AddSingleton<IExternalPlayerService, ExternalPlayerService>();

        // ViewModels
        builder.Services.AddTransient<SetupViewModel>();
        builder.Services.AddTransient<HomeViewModel>();
        builder.Services.AddTransient<BrowserViewModel>();
        builder.Services.AddTransient<VideoPlayerViewModel>();
        builder.Services.AddTransient<ImageGalleryViewModel>();
        builder.Services.AddTransient<ImagePickerViewModel>();
        builder.Services.AddSingleton<SettingsViewModel>();

        // Views
        builder.Services.AddTransient<SetupPage>();
        builder.Services.AddTransient<HomePage>();
        builder.Services.AddTransient<BrowserPage>();
        builder.Services.AddTransient<VideoPlayerPage>();
        builder.Services.AddTransient<ImageGalleryPage>();
        builder.Services.AddTransient<ImagePickerPage>();
        builder.Services.AddSingleton<SettingsPage>();

#if DEBUG
        builder.Logging.AddDebug();
#endif

        return builder.Build();
    }
}
