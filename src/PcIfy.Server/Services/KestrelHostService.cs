using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using PcIfy.Server.Api.Middleware;
using PcIfy.Server.Helpers;
using PcIfy.Server.Models;
using PcIfy.Server.Services.Interfaces;

namespace PcIfy.Server.Services;

public class KestrelHostService : IKestrelHostService
{
    private readonly AppSettings _settings;
    private readonly IConnectionLogService _logService;
    private readonly ISettingsService _settingsService;
    private IHost? _host;

    public bool IsRunning { get; private set; }
    public int? CurrentPort { get; private set; }
    public event EventHandler<bool>? RunningStateChanged;

    public KestrelHostService(AppSettings settings, IConnectionLogService logService, ISettingsService settingsService)
    {
        _settings = settings;
        _logService = logService;
        _settingsService = settingsService;
    }

    public async Task StartAsync(int port)
    {
        if (IsRunning) await StopAsync();

        _host = BuildHost(port);
        _ = _host.StartAsync();

        CurrentPort = port;
        IsRunning = true;
        RunningStateChanged?.Invoke(this, true);
    }

    public async Task StopAsync()
    {
        if (_host is not null)
        {
            await _host.StopAsync();
            _host.Dispose();
            _host = null;
        }
        IsRunning = false;
        CurrentPort = null;
        RunningStateChanged?.Invoke(this, false);
    }

    private IHost BuildHost(int port)
    {
        return Host.CreateDefaultBuilder()
            .ConfigureWebHostDefaults(web =>
            {
                web.UseKestrel(opts => opts.ListenAnyIP(port));
                web.Configure(ConfigureApp);
            })
            .ConfigureServices(services =>
            {
                services.AddSingleton(_settings);
                services.AddSingleton(_logService);
                services.AddSingleton<ISettingsService>(_settingsService);
                services.AddSingleton<IAuthService, AuthService>();
                services.AddSingleton<IFileService, FileService>();
                services.AddSingleton<IThumbnailService, ThumbnailService>();
                services.AddSingleton<ISystemControlService, WindowsSystemControlService>();

                services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
                    .AddJwtBearer(opts => JwtHelper.ConfigureJwtBearerOptions(opts, _settings.JwtSecret));

                services.AddAuthorization();
                services.AddControllers()
                    .AddJsonOptions(opts =>
                        opts.JsonSerializerOptions.Converters.Add(
                            new System.Text.Json.Serialization.JsonStringEnumConverter()));
                services.AddCors(opts => opts.AddDefaultPolicy(p =>
                    p.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));
            })
            .Build();
    }

    private static void ConfigureApp(IApplicationBuilder app)
    {
        app.UseCors();
        app.UseRouting();
        app.UseAuthentication();
        app.UseAuthorization();
        app.UseMiddleware<ConnectionLoggingMiddleware>();
        app.UseEndpoints(endpoints => endpoints.MapControllers());
    }
}
