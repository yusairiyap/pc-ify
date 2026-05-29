namespace PcIfy.Server.Forms;

partial class FFmpegDownloadDialog
{
    private System.ComponentModel.IContainer components = null;

    private System.Windows.Forms.Label lblTitle;
    private System.Windows.Forms.Label lblStatus;
    private System.Windows.Forms.ProgressBar progressBar;
    private System.Windows.Forms.Button btnSkip;

    protected override void Dispose(bool disposing)
    {
        if (disposing && (components != null))
            components.Dispose();
        base.Dispose(disposing);
    }

    private void InitializeComponent()
    {
        this.components = new System.ComponentModel.Container();
        this.lblTitle = new System.Windows.Forms.Label();
        this.lblStatus = new System.Windows.Forms.Label();
        this.progressBar = new System.Windows.Forms.ProgressBar();
        this.btnSkip = new System.Windows.Forms.Button();
        this.SuspendLayout();
        //
        // lblTitle
        //
        this.lblTitle.AutoSize = true;
        this.lblTitle.Font = new System.Drawing.Font("Segoe UI", 9F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point);
        this.lblTitle.Location = new System.Drawing.Point(16, 16);
        this.lblTitle.Name = "lblTitle";
        this.lblTitle.Size = new System.Drawing.Size(268, 15);
        this.lblTitle.TabIndex = 0;
        this.lblTitle.Text = "Downloading FFmpeg for video thumbnails…";
        //
        // lblStatus
        //
        this.lblStatus.Location = new System.Drawing.Point(16, 40);
        this.lblStatus.Name = "lblStatus";
        this.lblStatus.Size = new System.Drawing.Size(370, 18);
        this.lblStatus.TabIndex = 1;
        this.lblStatus.Text = "Starting download…";
        //
        // progressBar
        //
        this.progressBar.Location = new System.Drawing.Point(16, 64);
        this.progressBar.Maximum = 100;
        this.progressBar.Minimum = 0;
        this.progressBar.Name = "progressBar";
        this.progressBar.Size = new System.Drawing.Size(370, 20);
        this.progressBar.TabIndex = 2;
        //
        // btnSkip
        //
        this.btnSkip.FlatStyle = System.Windows.Forms.FlatStyle.System;
        this.btnSkip.Location = new System.Drawing.Point(236, 95);
        this.btnSkip.Name = "btnSkip";
        this.btnSkip.Size = new System.Drawing.Size(150, 26);
        this.btnSkip.TabIndex = 3;
        this.btnSkip.Text = "Skip (no video thumbnails)";
        this.btnSkip.UseVisualStyleBackColor = true;
        this.btnSkip.Click += new System.EventHandler(this.btnSkip_Click);
        //
        // FFmpegDownloadDialog
        //
        this.AutoScaleDimensions = new System.Drawing.SizeF(7F, 15F);
        this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
        this.ClientSize = new System.Drawing.Size(402, 136);
        this.Controls.Add(this.lblTitle);
        this.Controls.Add(this.lblStatus);
        this.Controls.Add(this.progressBar);
        this.Controls.Add(this.btnSkip);
        this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedDialog;
        this.MaximizeBox = false;
        this.MinimizeBox = false;
        this.Name = "FFmpegDownloadDialog";
        this.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen;
        this.Text = "pc-ify — FFmpeg Setup";
        this.Load += new System.EventHandler(this.OnLoad);
        this.ResumeLayout(false);
        this.PerformLayout();
    }
}
