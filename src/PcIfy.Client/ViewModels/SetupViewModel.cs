using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PcIfy.Client.Services.Interfaces;
using PcIfy.Client.ViewModels.Base;

namespace PcIfy.Client.ViewModels;

public partial class SetupViewModel : BaseViewModel
{
    private readonly IConnectionService _connection;
    private readonly IApiService _api;
    private readonly IAuthTokenService _tokenService;

    [ObservableProperty] private string _host = string.Empty;
    [ObservableProperty] private int _port = 8080;
    [ObservableProperty] private string _username = string.Empty;
    [ObservableProperty] private string _password = string.Empty;
    [ObservableProperty] private string? _serverName;
    [ObservableProperty] private bool _isConnected;
    [ObservableProperty] private bool _showLoginSection;
    [ObservableProperty] private string _statusMessage = string.Empty;

    public SetupViewModel(IConnectionService connection, IApiService api, IAuthTokenService tokenService)
    {
        _connection = connection;
        _api = api;
        _tokenService = tokenService;
        Title = "Connect to pc-ify";

        // Pre-populate from saved connection
        if (!string.IsNullOrEmpty(connection.BaseUrl))
        {
            var uri = new Uri(connection.BaseUrl);
            Host = uri.Host;
            Port = uri.Port;
        }
    }

    [RelayCommand]
    private async Task TestConnectionAsync()
    {
        if (string.IsNullOrWhiteSpace(Host)) return;
        IsBusy = true;
        StatusMessage = "Connecting…";
        ShowLoginSection = false;

        try
        {
            await _connection.SetConnectionAsync(Host.Trim(), Port);
            var ok = await _connection.TestConnectionAsync();
            if (ok)
            {
                var info = await _api.GetServerInfoAsync();
                ServerName = info?.ServerName ?? "pc-ify Server";
                IsConnected = true;
                ShowLoginSection = true;
                StatusMessage = $"Connected to {ServerName}";
            }
            else
            {
                IsConnected = false;
                StatusMessage = "Cannot reach server. Check IP and port.";
            }
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task LoginAsync()
    {
        if (string.IsNullOrWhiteSpace(Username) || string.IsNullOrWhiteSpace(Password)) return;
        IsBusy = true;
        StatusMessage = "Authenticating…";

        try
        {
            var response = await _api.LoginAsync(Username, Password);
            if (response is not null)
            {
                await _tokenService.SaveTokenAsync(response.Token);
                await Shell.Current.GoToAsync("//home");
            }
            else
            {
                StatusMessage = "Invalid username or password.";
            }
        }
        finally { IsBusy = false; }
    }
}
