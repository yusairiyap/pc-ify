using System.IO.Compression;
using System.Text.Json;
using PcIfy.Server.Helpers;
using PcIfy.Server.Models;
using PcIfy.Server.Services;
using PcIfy.Server.Services.Interfaces;

namespace PcIfy.Server.Forms;

public partial class SettingsForm : Form
{
    private readonly AppSettings _settings;
    private readonly ISettingsService _settingsService;
    private readonly IKestrelHostService _kestrel;

    // Tracks which user's directory checkboxes are currently loaded in clbUserDirs.
    private string? _currentUsername;
    // Suppress SelectedIndexChanged handler re-entrancy while loading.
    private bool _loadingUserDirs;

    public SettingsForm(AppSettings settings, ISettingsService settingsService, IKestrelHostService kestrel)
    {
        _settings = settings;
        _settingsService = settingsService;
        _kestrel = kestrel;
        InitializeComponent();
        Program.ApplyButtonStyles(this, Program.IsCurrentlyDark(settings.ColorMode));
        LoadSettings();
    }

    private void LoadSettings()
    {
        nudPort.Value = _settings.Port;
        chkAutoStart.Checked = _settings.AutoStart;
        txtServerName.Text = _settings.ServerName;

        cmbColorMode.Items.Clear();
        cmbColorMode.Items.AddRange(["System", "Dark", "Light"]);
        cmbColorMode.SelectedItem = _settings.ColorMode;

        lstDirectories.Items.Clear();
        foreach (var dir in _settings.SourceDirectories)
            lstDirectories.Items.Add(dir);

        _currentUsername = null;
        clbUserDirs.Items.Clear();

        lstUsers.Items.Clear();
        foreach (var user in _settings.Users)
            lstUsers.Items.Add(user.Username);
    }

    // ── Save ──────────────────────────────────────────────────────────────────

    private void btnSave_Click(object sender, EventArgs e)
    {
        SaveCurrentUserDirs();

        var newPort = (int)nudPort.Value;
        var portChanged = newPort != _settings.Port;

        _settings.Port = newPort;
        _settings.AutoStart = chkAutoStart.Checked;
        _settings.ServerName = txtServerName.Text.Trim();
        _settings.ColorMode = cmbColorMode.SelectedItem?.ToString() ?? "System";
        _settingsService.Save(_settings);

        Program.ApplyColorMode(_settings.ColorMode);

        if (portChanged && _kestrel.IsRunning)
            MessageBox.Show("Port changed. Restart the server for the new port to take effect.",
                "Restart Required", MessageBoxButtons.OK, MessageBoxIcon.Information);

        DialogResult = DialogResult.OK;
        Close();
    }

    // ── Directories ───────────────────────────────────────────────────────────

    private void btnAddDir_Click(object sender, EventArgs e)
    {
        using var dialog = new FolderBrowserDialog { Description = "Select a source directory to share" };
        if (dialog.ShowDialog() != DialogResult.OK) return;
        if (!lstDirectories.Items.Contains(dialog.SelectedPath))
        {
            lstDirectories.Items.Add(dialog.SelectedPath);
            _settings.SourceDirectories.Add(dialog.SelectedPath);
            // Refresh directory list in clbUserDirs so newly added dir appears.
            RefreshUserDirsAfterDirectoryChange();
        }
    }

    private void btnRemoveDir_Click(object sender, EventArgs e)
    {
        if (lstDirectories.SelectedItem is not string selected) return;

        lstDirectories.Items.Remove(selected);
        _settings.SourceDirectories.Remove(selected);

        // Remove this directory from every user's allowed list.
        foreach (var u in _settings.Users)
            u.AllowedDirectories.Remove(selected);

        RefreshUserDirsAfterDirectoryChange();
    }

    private void RefreshUserDirsAfterDirectoryChange()
    {
        SaveCurrentUserDirs();
        LoadUserDirs(_currentUsername);
    }

    // ── Users ─────────────────────────────────────────────────────────────────

    private void btnAddUser_Click(object sender, EventArgs e)
    {
        using var dlg = new AddUserDialog();
        if (dlg.ShowDialog(this) != DialogResult.OK) return;
        if (string.IsNullOrWhiteSpace(dlg.Username)) return;

        _settings.Users.RemoveAll(u => string.Equals(u.Username, dlg.Username, StringComparison.OrdinalIgnoreCase));
        _settings.Users.Add(new UserCredential
        {
            Username = dlg.Username,
            PasswordHash = PasswordHasher.Hash(dlg.Password)
        });

        lstUsers.Items.Clear();
        foreach (var user in _settings.Users)
            lstUsers.Items.Add(user.Username);
    }

    private void btnRemoveUser_Click(object sender, EventArgs e)
    {
        if (lstUsers.SelectedItem is not string selected) return;

        if (string.Equals(_currentUsername, selected, StringComparison.OrdinalIgnoreCase))
        {
            _currentUsername = null;
            clbUserDirs.Items.Clear();
        }

        _settings.Users.RemoveAll(u => string.Equals(u.Username, selected, StringComparison.OrdinalIgnoreCase));
        lstUsers.Items.Remove(selected);
    }

    // ── User directory assignment ─────────────────────────────────────────────

    private void lstUsers_SelectedIndexChanged(object sender, EventArgs e)
    {
        if (_loadingUserDirs) return;
        SaveCurrentUserDirs();
        _currentUsername = lstUsers.SelectedItem as string;
        LoadUserDirs(_currentUsername);
    }

    private void SaveCurrentUserDirs()
    {
        if (_currentUsername is null) return;
        var user = _settings.Users.FirstOrDefault(u =>
            string.Equals(u.Username, _currentUsername, StringComparison.OrdinalIgnoreCase));
        if (user is null) return;

        var checkedDirs = clbUserDirs.CheckedItems.Cast<string>().ToList();
        // All checked = unrestricted (empty list); partial = restricted.
        user.AllowedDirectories = checkedDirs.Count == _settings.SourceDirectories.Count
            ? []
            : checkedDirs;
    }

    private void LoadUserDirs(string? username)
    {
        _loadingUserDirs = true;
        try
        {
            clbUserDirs.Items.Clear();
            if (username is null) return;

            var user = _settings.Users.FirstOrDefault(u =>
                string.Equals(u.Username, username, StringComparison.OrdinalIgnoreCase));
            if (user is null) return;

            foreach (var dir in _settings.SourceDirectories)
            {
                var isChecked = user.AllowedDirectories.Count == 0
                    || user.AllowedDirectories.Contains(dir, StringComparer.OrdinalIgnoreCase);
                clbUserDirs.Items.Add(dir, isChecked);
            }
        }
        finally
        {
            _loadingUserDirs = false;
        }
    }

    // ── Import / Export ───────────────────────────────────────────────────────

    private void btnExport_Click(object sender, EventArgs e)
    {
        SaveCurrentUserDirs();

        using var dlg = new SaveFileDialog
        {
            Title = "Export Settings",
            Filter = "ZIP archive (*.zip)|*.zip",
            FileName = "pcify-settings.zip",
            DefaultExt = "zip"
        };
        if (dlg.ShowDialog(this) != DialogResult.OK) return;

        try
        {
            var jsonBytes = System.Text.Encoding.UTF8.GetBytes(
                JsonSerializer.Serialize(_settings, SettingsService.JsonOptions));

            using var ms = new MemoryStream();
            using (var zip = new ZipArchive(ms, ZipArchiveMode.Create, leaveOpen: true))
            {
                var entry = zip.CreateEntry("settings.json", CompressionLevel.Optimal);
                using var entryStream = entry.Open();
                entryStream.Write(jsonBytes);
            }
            File.WriteAllBytes(dlg.FileName, ms.ToArray());
            MessageBox.Show($"Settings exported to:\n{dlg.FileName}",
                "Export Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Export failed:\n{ex.Message}",
                "Export Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void btnImport_Click(object sender, EventArgs e)
    {
        using var dlg = new OpenFileDialog
        {
            Title = "Import Settings",
            Filter = "ZIP archive (*.zip)|*.zip"
        };
        if (dlg.ShowDialog(this) != DialogResult.OK) return;

        try
        {
            using var zip = ZipFile.OpenRead(dlg.FileName);
            var entry = zip.GetEntry("settings.json");
            if (entry is null)
            {
                MessageBox.Show("Invalid file: settings.json not found in ZIP.",
                    "Import Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            using var reader = new System.IO.StreamReader(entry.Open());
            var json = reader.ReadToEnd();
            var imported = JsonSerializer.Deserialize<AppSettings>(json,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            if (imported is null) throw new Exception("Deserialization returned null.");

            _settings.Port = imported.Port;
            _settings.AutoStart = imported.AutoStart;
            _settings.ServerName = imported.ServerName;
            _settings.JwtSecret = imported.JwtSecret;
            _settings.TokenExpiryHours = imported.TokenExpiryHours;
            _settings.Users = imported.Users;
            _settings.SourceDirectories = imported.SourceDirectories;
            _settings.ColorMode = imported.ColorMode;

            LoadSettings();
            MessageBox.Show("Settings imported. Review and click Save to apply.",
                "Import Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Import failed:\n{ex.Message}",
                "Import Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
