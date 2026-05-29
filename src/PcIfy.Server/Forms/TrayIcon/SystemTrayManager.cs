using PcIfy.Server.Models;
using PcIfy.Server.Services.Interfaces;

namespace PcIfy.Server.Forms.TrayIcon;

public class SystemTrayManager : IDisposable
{
    private readonly NotifyIcon _notifyIcon;
    private readonly ToolStripMenuItem _toggleServerItem;
    private readonly ToolStripMenuItem _toggleThemeItem;
    private readonly Form _mainForm;
    private readonly IKestrelHostService _kestrel;
    private readonly AppSettings _settings;
    private readonly ISettingsService _settingsService;

    public SystemTrayManager(Form mainForm, IKestrelHostService kestrel, AppSettings settings, ISettingsService settingsService)
    {
        _mainForm = mainForm;
        _kestrel = kestrel;
        _settings = settings;
        _settingsService = settingsService;

        _toggleServerItem = new ToolStripMenuItem("Start Server", null, OnToggleServer);
        _toggleThemeItem = new ToolStripMenuItem("Toggle Dark/Light", null, OnToggleTheme);

        var contextMenu = new ContextMenuStrip();
        contextMenu.Items.Add(new ToolStripMenuItem("Show pc-ify", null, OnShow));
        contextMenu.Items.Add(new ToolStripSeparator());
        contextMenu.Items.Add(_toggleServerItem);
        contextMenu.Items.Add(_toggleThemeItem);
        contextMenu.Items.Add(new ToolStripSeparator());
        contextMenu.Items.Add(new ToolStripMenuItem("Exit", null, OnExit));

        _notifyIcon = new NotifyIcon
        {
            Text = "pc-ify",
            Icon = SystemIcons.Application,
            ContextMenuStrip = contextMenu,
            Visible = true
        };
        _notifyIcon.DoubleClick += OnShow;

        _kestrel.RunningStateChanged += OnServerStateChanged;
        UpdateIcon(false);
        UpdateToggleThemeLabel(settings.ColorMode);
    }

    public void ShowBalloon(string title, string message, ToolTipIcon icon = ToolTipIcon.Info) =>
        _notifyIcon.ShowBalloonTip(3000, title, message, icon);

    private void OnServerStateChanged(object? sender, bool running)
    {
        if (_mainForm.IsHandleCreated)
            _mainForm.Invoke(() => UpdateIcon(running));
    }

    private void UpdateIcon(bool running)
    {
        _notifyIcon.Icon = running ? SystemIcons.Information : SystemIcons.Application;
        _notifyIcon.Text = running ? $"pc-ify — Running on port {_kestrel.CurrentPort}" : "pc-ify — Stopped";
        _toggleServerItem.Text = running ? "Stop Server" : "Start Server";
    }

    private async void OnToggleServer(object? sender, EventArgs e)
    {
        if (_kestrel.IsRunning)
            await _kestrel.StopAsync();
        else
            await _kestrel.StartAsync(_settings.Port);
    }

    private void OnToggleTheme(object? sender, EventArgs e)
    {
        var newMode = IsCurrentlyDark() ? "Light" : "Dark";
        Program.ApplyColorMode(newMode);
        _settings.ColorMode = newMode;
        _settingsService.Save(_settings);
        UpdateToggleThemeLabel(newMode);
    }

    private void UpdateToggleThemeLabel(string mode) =>
        _toggleThemeItem.Text = Program.IsCurrentlyDark(mode) ? "Switch to Light" : "Switch to Dark";

    private bool IsCurrentlyDark() => Program.IsCurrentlyDark(_settings.ColorMode);

    private void OnShow(object? sender, EventArgs e)
    {
        _mainForm.Show();
        _mainForm.WindowState = FormWindowState.Normal;
        _mainForm.BringToFront();
    }

    private void OnExit(object? sender, EventArgs e)
    {
        _notifyIcon.Visible = false;
        Application.Exit();
    }

    public void Dispose()
    {
        _notifyIcon.Dispose();
    }
}
