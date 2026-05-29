using Microsoft.Extensions.DependencyInjection;
using PcIfy.Server.Forms.TrayIcon;
using PcIfy.Server.Models;
using PcIfy.Server.Services.Interfaces;

namespace PcIfy.Server.Forms;

public partial class MainForm : Form
{
    private readonly IServiceProvider _services;
    private readonly IKestrelHostService _kestrel;
    private readonly IConnectionLogService _logService;
    private readonly AppSettings _settings;
    private readonly ISettingsService _settingsService;
    private SystemTrayManager? _trayManager;
    private bool _isClosing;

    public MainForm(IServiceProvider services)
    {
        _services = services;
        _kestrel = services.GetRequiredService<IKestrelHostService>();
        _logService = services.GetRequiredService<IConnectionLogService>();
        _settings = services.GetRequiredService<AppSettings>();
        _settingsService = services.GetRequiredService<ISettingsService>();

        InitializeComponent();
        SetupEventHandlers();
        Program.ApplyButtonStyles(this, Program.IsCurrentlyDark(_settings.ColorMode));
    }

    private void SetupEventHandlers()
    {
        _kestrel.RunningStateChanged += OnServerStateChanged;
        _logService.NewEntry += OnNewLogEntry;
        Load += OnLoad;
        Resize += OnFormResize;
        FormClosing += OnFormClosing;
    }

    private async void OnLoad(object? sender, EventArgs e)
    {
        _trayManager = new SystemTrayManager(this, _kestrel, _settings, _settingsService);
        UpdateServerStatus(false);
        UpdateThemeButton(_settings.ColorMode);

        await EnsureFfmpegAsync();

        if (_settings.AutoStart && _settings.SourceDirectories.Count > 0 && _settings.Users.Count > 0)
        {
            await _kestrel.StartAsync(_settings.Port);
        }
        else if (_settings.AutoStart)
        {
            SetStatus("Configure source directories and users before starting.", Color.Orange);
        }
    }

    private async Task EnsureFfmpegAsync()
    {
        if (Services.FFmpegSetupService.IsAvailable)
        {
            Services.FFmpegSetupService.Configure();
            return;
        }

        var result = MessageBox.Show(
            "FFmpeg is not installed. Download it now for video thumbnail support?\n\n(~30 MB — only needed once)",
            "FFmpeg Setup", MessageBoxButtons.YesNo, MessageBoxIcon.Question);

        if (result == DialogResult.Yes)
        {
            using var dlg = new FFmpegDownloadDialog();
            dlg.ShowDialog(this);
        }
    }

    private void OnFormResize(object? sender, EventArgs e)
    {
        if (WindowState == FormWindowState.Minimized)
        {
            Hide();
            _trayManager?.ShowBalloon("pc-ify", "Running in background.");
        }
    }

    private void OnFormClosing(object? sender, FormClosingEventArgs e)
    {
        if (!_isClosing && e.CloseReason == CloseReason.UserClosing)
        {
            e.Cancel = true;
            Hide();
            _trayManager?.ShowBalloon("pc-ify", "Still running. Right-click tray icon to exit.");
        }
    }

    private void OnServerStateChanged(object? sender, bool running)
    {
        if (InvokeRequired)
            Invoke(() => UpdateServerStatus(running));
        else
            UpdateServerStatus(running);
    }

    private void OnNewLogEntry(object? sender, ConnectionLogEntry entry)
    {
        if (InvokeRequired)
            Invoke(() => AddLogRow(entry));
        else
            AddLogRow(entry);
    }

    private void UpdateServerStatus(bool running)
    {
        btnStartStop.Text = running ? "Stop Server" : "Start Server";
        if (running)
            SetStatus($"Running", Color.LimeGreen);
        else
            SetStatus("Stopped", SystemColors.GrayText);

        lblPort.Text = $"{_settings.Port}";
        UpdateConnectAddress(running);
    }

    private void UpdateConnectAddress(bool running)
    {
        if (!running)
        {
            lblConnectAddress.Text = "— (server not running)";
            lblConnectAddress.ForeColor = SystemColors.GrayText;
            btnCopyAddress.Visible = false;
            return;
        }

        var ips = Helpers.NetworkHelper.GetLocalIpAddresses();
        if (ips.Count == 0)
        {
            lblConnectAddress.Text = $"localhost:{_kestrel.CurrentPort}";
        }
        else if (ips.Count == 1)
        {
            lblConnectAddress.Text = $"{ips[0]}:{_kestrel.CurrentPort}";
        }
        else
        {
            // Multiple IPs — show them all separated by  |
            lblConnectAddress.Text = string.Join("  |  ", ips.Select(ip => $"{ip}:{_kestrel.CurrentPort}"));
        }

        lblConnectAddress.ForeColor = Color.FromArgb(100, 180, 255);
        btnCopyAddress.Visible = true;
    }

    private void btnCopyAddress_Click(object sender, EventArgs e)
    {
        var ips = Helpers.NetworkHelper.GetLocalIpAddresses();
        var address = ips.Count > 0
            ? $"{ips[0]}:{_kestrel.CurrentPort}"
            : lblConnectAddress.Text;

        Clipboard.SetText(address);
        toolStripStatus.Text = $"Copied: {address}";

        // Reset status bar text after 3 seconds
        var timer = new System.Windows.Forms.Timer { Interval = 3000 };
        timer.Tick += (_, _) => { toolStripStatus.Text = "pc-ify ready"; timer.Dispose(); };
        timer.Start();
    }

    private void SetStatus(string text, Color color)
    {
        lblStatus.Text = text;
        lblStatus.ForeColor = color;
    }

    private void AddLogRow(ConnectionLogEntry entry)
    {
        var row = new DataGridViewRow();
        row.CreateCells(dgvLog,
            entry.Timestamp.ToString("HH:mm:ss"),
            entry.ClientIp,
            entry.Username,
            entry.Method,
            entry.Path,
            entry.StatusCode.ToString());

        row.DefaultCellStyle.ForeColor = entry.StatusCode >= 400 ? Color.IndianRed : SystemColors.ControlText;
        dgvLog.Rows.Insert(0, row);

        if (dgvLog.Rows.Count > 500)
            dgvLog.Rows.RemoveAt(dgvLog.Rows.Count - 1);
    }

    private async void btnStartStop_Click(object sender, EventArgs e)
    {
        if (_kestrel.IsRunning)
        {
            await _kestrel.StopAsync();
        }
        else
        {
            if (_settings.SourceDirectories.Count == 0)
            {
                MessageBox.Show("Add at least one source directory in Settings.", "pc-ify", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            await _kestrel.StartAsync(_settings.Port);
        }
    }

    private void btnSettings_Click(object sender, EventArgs e)
    {
        using var form = new SettingsForm(_settings, _settingsService, _kestrel);
        form.ShowDialog(this);
        // Refresh button label in case color mode was changed in Settings
        UpdateThemeButton(_settings.ColorMode);
        lblPort.Text = $"{_settings.Port}";
    }

    private void btnClearLog_Click(object sender, EventArgs e) => dgvLog.Rows.Clear();

    private void btnThemeToggle_Click(object sender, EventArgs e)
    {
        var newMode = IsCurrentlyDark() ? "Light" : "Dark";
        Program.ApplyColorMode(newMode);
        _settings.ColorMode = newMode;
        _settingsService.Save(_settings);
        UpdateThemeButton(newMode);
    }

    private void UpdateThemeButton(string mode) =>
        btnThemeToggle.Text = Program.IsCurrentlyDark(mode) ? "Light Mode" : "Dark Mode";

    private bool IsCurrentlyDark() => Program.IsCurrentlyDark(_settings.ColorMode);

    public void ExitApplication()
    {
        _isClosing = true;
        Application.Exit();
    }
}
