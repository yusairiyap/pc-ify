using PcIfy.Server.Helpers;
using PcIfy.Server.Models;
using PcIfy.Server.Services.Interfaces;

namespace PcIfy.Server.Forms;

public partial class SettingsForm : Form
{
    private readonly AppSettings _settings;
    private readonly ISettingsService _settingsService;
    private readonly IKestrelHostService _kestrel;

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

        lstUsers.Items.Clear();
        foreach (var user in _settings.Users)
            lstUsers.Items.Add(user.Username);
    }

    private void btnSave_Click(object sender, EventArgs e)
    {
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

    private void btnAddDir_Click(object sender, EventArgs e)
    {
        using var dialog = new FolderBrowserDialog { Description = "Select a source directory to share" };
        if (dialog.ShowDialog() != DialogResult.OK) return;
        if (!lstDirectories.Items.Contains(dialog.SelectedPath))
        {
            lstDirectories.Items.Add(dialog.SelectedPath);
            _settings.SourceDirectories.Add(dialog.SelectedPath);
        }
    }

    private void btnRemoveDir_Click(object sender, EventArgs e)
    {
        if (lstDirectories.SelectedItem is string selected)
        {
            lstDirectories.Items.Remove(selected);
            _settings.SourceDirectories.Remove(selected);
        }
    }

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
        if (lstUsers.SelectedItem is string selected)
        {
            _settings.Users.RemoveAll(u => string.Equals(u.Username, selected, StringComparison.OrdinalIgnoreCase));
            lstUsers.Items.Remove(selected);
        }
    }
}
