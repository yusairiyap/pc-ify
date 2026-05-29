using System.Runtime.InteropServices;
using Microsoft.Extensions.DependencyInjection;
using PcIfy.Server.Forms;
using PcIfy.Server.Models;
using PcIfy.Server.Services;
using PcIfy.Server.Services.Interfaces;

namespace PcIfy.Server;

internal static class Program
{
    private const int DwmwaUseImmersiveDarkMode = 20;
    private const int WmThemeChanged = 0x031A;

    [DllImport("dwmapi.dll", PreserveSig = false)]
    private static extern void DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);

    [STAThread]
    static void Main()
    {
        Application.SetHighDpiMode(HighDpiMode.SystemAware);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        var settingsService = new SettingsService();
        var settings = settingsService.Load();

        ApplyColorMode(settings.ColorMode);

        var services = new ServiceCollection();
        services.AddSingleton<ISettingsService>(settingsService);
        services.AddSingleton(settings);
        services.AddSingleton<IConnectionLogService, ConnectionLogService>();
        services.AddSingleton<IKestrelHostService, KestrelHostService>();
        var provider = services.BuildServiceProvider();

        Application.Run(new MainForm(provider));
    }

    internal static void ApplyColorMode(string mode)
    {
        var colorMode = mode.ToLowerInvariant() switch
        {
            "dark"  => SystemColorMode.Dark,
            "light" => SystemColorMode.Classic,
            _       => SystemColorMode.System
        };

        Application.SetColorMode(colorMode);

        var isDark = colorMode == SystemColorMode.Dark ||
                     (colorMode == SystemColorMode.System && IsSystemDark());
        int darkFlag = isDark ? 1 : 0;

        foreach (Form form in Application.OpenForms.Cast<Form>().ToList())
        {
            // Title bar — DWM non-client area colour
            try { DwmSetWindowAttribute(form.Handle, DwmwaUseImmersiveDarkMode, ref darkFlag, sizeof(int)); }
            catch { /* DWM unavailable on older Windows */ }

            // Apply Flat style + SystemColors to all buttons so WinForms draws them
            // (FlatStyle.System uses uxtheme which has no dark variant for buttons)
            ApplyButtonStyles(form, isDark);

            // Force every control's visual-style renderer to re-query the current theme
            BroadcastThemeChanged(form);

            form.Invalidate(true);
            form.Update();
        }
    }

    internal static bool IsCurrentlyDark(string colorMode) =>
        colorMode.ToLowerInvariant() == "dark" ||
        (colorMode.ToLowerInvariant() == "system" && IsSystemDark());

    // Uses explicit Color values keyed on isDark rather than SystemColors, because
    // SystemColors.Control captures the current value as a struct — if SetColorMode
    // hasn't fully propagated yet the wrong color would be stored on the button.
    internal static void ApplyButtonStyles(Control control, bool isDark)
    {
        if (control is Button btn)
        {
            btn.FlatStyle = FlatStyle.Flat;
            if (isDark)
            {
                btn.BackColor = Color.FromArgb(62, 62, 62);
                btn.ForeColor = Color.White;
                btn.FlatAppearance.BorderColor         = Color.FromArgb(85, 85, 85);
                btn.FlatAppearance.MouseOverBackColor  = Color.FromArgb(80, 80, 80);
                btn.FlatAppearance.MouseDownBackColor  = Color.FromArgb(45, 45, 45);
            }
            else
            {
                btn.BackColor = Color.FromArgb(225, 225, 225);
                btn.ForeColor = Color.Black;
                btn.FlatAppearance.BorderColor         = Color.FromArgb(180, 180, 180);
                btn.FlatAppearance.MouseOverBackColor  = Color.FromArgb(210, 210, 210);
                btn.FlatAppearance.MouseDownBackColor  = Color.FromArgb(195, 195, 195);
            }
        }

        foreach (Control child in control.Controls)
            ApplyButtonStyles(child, isDark);
    }

    private static void BroadcastThemeChanged(Control control)
    {
        if (control.IsHandleCreated)
            SendMessage(control.Handle, WmThemeChanged, IntPtr.Zero, IntPtr.Zero);
        foreach (Control child in control.Controls)
            BroadcastThemeChanged(child);
    }

    internal static bool IsSystemDark()
    {
        try
        {
            using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return key?.GetValue("AppsUseLightTheme") is int i && i == 0;
        }
        catch { return false; }
    }
}
