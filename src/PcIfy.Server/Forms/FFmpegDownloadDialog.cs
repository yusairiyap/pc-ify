using PcIfy.Server.Services;

namespace PcIfy.Server.Forms;

public partial class FFmpegDownloadDialog : Form
{
    private Task? _downloadTask;

    public bool Succeeded { get; private set; }

    public FFmpegDownloadDialog()
    {
        InitializeComponent();
    }

    private void OnLoad(object? sender, EventArgs e)
    {
        var progress = new Progress<(string message, int percent)>(report =>
        {
            if (InvokeRequired)
                Invoke(() => UpdateProgress(report.message, report.percent));
            else
                UpdateProgress(report.message, report.percent);
        });

        _downloadTask = Task.Run(async () =>
        {
            try
            {
                await FFmpegSetupService.EnsureAvailableAsync(progress);
                Invoke(() =>
                {
                    Succeeded = true;
                    DialogResult = DialogResult.OK;
                    Close();
                });
            }
            catch (Exception ex)
            {
                Invoke(() =>
                {
                    MessageBox.Show($"FFmpeg download failed: {ex.Message}\n\nVideo thumbnails will be unavailable.",
                        "Download Failed", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    DialogResult = DialogResult.Cancel;
                    Close();
                });
            }
        });
    }

    private void UpdateProgress(string message, int percent)
    {
        lblStatus.Text = message;
        progressBar.Value = Math.Clamp(percent, 0, 100);
    }

    private void btnSkip_Click(object sender, EventArgs e)
    {
        DialogResult = DialogResult.Cancel;
        Close();
    }
}
