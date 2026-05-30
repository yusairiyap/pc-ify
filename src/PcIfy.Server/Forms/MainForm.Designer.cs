namespace PcIfy.Server.Forms;

partial class MainForm
{
    private System.ComponentModel.IContainer components = null;

    private System.Windows.Forms.Label lblTitle;
    private System.Windows.Forms.Label lblStatusLabel;
    private System.Windows.Forms.Label lblStatus;
    private System.Windows.Forms.Label lblPortLabel;
    private System.Windows.Forms.Label lblPort;
    private System.Windows.Forms.Button btnStartStop;
    private System.Windows.Forms.Button btnSettings;
    private System.Windows.Forms.Button btnClearLog;
    private System.Windows.Forms.Button btnThemeToggle;
    private System.Windows.Forms.DataGridView dgvLog;
    private System.Windows.Forms.DataGridViewTextBoxColumn colTime;
    private System.Windows.Forms.DataGridViewTextBoxColumn colIp;
    private System.Windows.Forms.DataGridViewTextBoxColumn colUser;
    private System.Windows.Forms.DataGridViewTextBoxColumn colMethod;
    private System.Windows.Forms.DataGridViewTextBoxColumn colPath;
    private System.Windows.Forms.DataGridViewTextBoxColumn colStatus;
    private System.Windows.Forms.StatusStrip statusStrip;
    private System.Windows.Forms.ToolStripStatusLabel toolStripStatus;
    private System.Windows.Forms.Label lblConnectLabel;
    private System.Windows.Forms.Label lblConnectAddress;
    private System.Windows.Forms.Button btnCopyAddress;

    protected override void Dispose(bool disposing)
    {
        if (disposing && (components != null))
            components.Dispose();
        _trayManager?.Dispose();
        base.Dispose(disposing);
    }

    private void InitializeComponent()
    {
        lblTitle = new Label();
        lblStatusLabel = new Label();
        lblStatus = new Label();
        lblPortLabel = new Label();
        lblPort = new Label();
        btnStartStop = new Button();
        btnSettings = new Button();
        btnClearLog = new Button();
        btnThemeToggle = new Button();
        dgvLog = new DataGridView();
        colTime = new DataGridViewTextBoxColumn();
        colIp = new DataGridViewTextBoxColumn();
        colUser = new DataGridViewTextBoxColumn();
        colMethod = new DataGridViewTextBoxColumn();
        colPath = new DataGridViewTextBoxColumn();
        colStatus = new DataGridViewTextBoxColumn();
        statusStrip = new StatusStrip();
        toolStripStatus = new ToolStripStatusLabel();
        lblConnectLabel = new Label();
        lblConnectAddress = new Label();
        btnCopyAddress = new Button();
        ((System.ComponentModel.ISupportInitialize)dgvLog).BeginInit();
        statusStrip.SuspendLayout();
        SuspendLayout();
        // 
        // lblTitle
        // 
        lblTitle.AutoSize = true;
        lblTitle.Font = new Font("Segoe UI", 16F, FontStyle.Bold);
        lblTitle.Location = new Point(17, 20);
        lblTitle.Margin = new Padding(4, 0, 4, 0);
        lblTitle.Name = "lblTitle";
        lblTitle.Size = new Size(107, 45);
        lblTitle.TabIndex = 0;
        lblTitle.Text = "pc-ify";
        // 
        // lblStatusLabel
        // 
        lblStatusLabel.AutoSize = true;
        lblStatusLabel.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
        lblStatusLabel.Location = new Point(17, 92);
        lblStatusLabel.Margin = new Padding(4, 0, 4, 0);
        lblStatusLabel.Name = "lblStatusLabel";
        lblStatusLabel.Size = new Size(70, 25);
        lblStatusLabel.TabIndex = 1;
        lblStatusLabel.Text = "Status:";
        // 
        // lblStatus
        // 
        lblStatus.AutoSize = true;
        lblStatus.ForeColor = SystemColors.GrayText;
        lblStatus.Location = new Point(93, 92);
        lblStatus.Margin = new Padding(4, 0, 4, 0);
        lblStatus.Name = "lblStatus";
        lblStatus.Size = new Size(80, 25);
        lblStatus.TabIndex = 2;
        lblStatus.Text = "Stopped";
        // 
        // lblPortLabel
        // 
        lblPortLabel.Anchor = AnchorStyles.Top | AnchorStyles.Right;
        lblPortLabel.AutoSize = true;
        lblPortLabel.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
        lblPortLabel.Location = new Point(948, 92);
        lblPortLabel.Margin = new Padding(4, 0, 4, 0);
        lblPortLabel.Name = "lblPortLabel";
        lblPortLabel.Size = new Size(53, 25);
        lblPortLabel.TabIndex = 3;
        lblPortLabel.Text = "Port:";
        // 
        // lblPort
        // 
        lblPort.Anchor = AnchorStyles.Top | AnchorStyles.Right;
        lblPort.AutoSize = true;
        lblPort.Location = new Point(1009, 92);
        lblPort.Margin = new Padding(4, 0, 4, 0);
        lblPort.Name = "lblPort";
        lblPort.Size = new Size(52, 25);
        lblPort.TabIndex = 4;
        lblPort.Text = "8080";
        // 
        // btnStartStop
        // 
        btnStartStop.FlatStyle = FlatStyle.System;
        btnStartStop.Location = new Point(17, 137);
        btnStartStop.Margin = new Padding(4, 5, 4, 5);
        btnStartStop.Name = "btnStartStop";
        btnStartStop.Size = new Size(157, 53);
        btnStartStop.TabIndex = 5;
        btnStartStop.Text = "Start Server";
        btnStartStop.UseVisualStyleBackColor = true;
        btnStartStop.Click += btnStartStop_Click;
        // 
        // btnSettings
        // 
        btnSettings.FlatStyle = FlatStyle.System;
        btnSettings.Location = new Point(186, 137);
        btnSettings.Margin = new Padding(4, 5, 4, 5);
        btnSettings.Name = "btnSettings";
        btnSettings.Size = new Size(114, 53);
        btnSettings.TabIndex = 6;
        btnSettings.Text = "Settings";
        btnSettings.UseVisualStyleBackColor = true;
        btnSettings.Click += btnSettings_Click;
        // 
        // btnClearLog
        // 
        btnClearLog.FlatStyle = FlatStyle.System;
        btnClearLog.Location = new Point(451, 137);
        btnClearLog.Margin = new Padding(4, 5, 4, 5);
        btnClearLog.Name = "btnClearLog";
        btnClearLog.Size = new Size(114, 53);
        btnClearLog.TabIndex = 8;
        btnClearLog.Text = "Clear Log";
        btnClearLog.UseVisualStyleBackColor = true;
        btnClearLog.Click += btnClearLog_Click;
        // 
        // btnThemeToggle
        // 
        btnThemeToggle.FlatStyle = FlatStyle.System;
        btnThemeToggle.Location = new Point(311, 137);
        btnThemeToggle.Margin = new Padding(4, 5, 4, 5);
        btnThemeToggle.Name = "btnThemeToggle";
        btnThemeToggle.Size = new Size(129, 53);
        btnThemeToggle.TabIndex = 7;
        btnThemeToggle.Text = "Dark Mode";
        btnThemeToggle.UseVisualStyleBackColor = true;
        btnThemeToggle.Click += btnThemeToggle_Click;
        // 
        // dgvLog
        // 
        dgvLog.AllowUserToAddRows = false;
        dgvLog.AllowUserToDeleteRows = false;
        dgvLog.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
        dgvLog.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        dgvLog.BackgroundColor = SystemColors.Window;
        dgvLog.BorderStyle = BorderStyle.None;
        dgvLog.ColumnHeadersHeight = 34;
        dgvLog.Columns.AddRange(new DataGridViewColumn[] { colTime, colIp, colUser, colMethod, colPath, colStatus });
        dgvLog.EnableHeadersVisualStyles = false;
        dgvLog.GridColor = SystemColors.ControlLight;
        dgvLog.Location = new Point(17, 245);
        dgvLog.Margin = new Padding(4, 5, 4, 5);
        dgvLog.Name = "dgvLog";
        dgvLog.ReadOnly = true;
        dgvLog.RowHeadersVisible = false;
        dgvLog.RowHeadersWidth = 62;
        dgvLog.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
        dgvLog.Size = new Size(1190, 667);
        dgvLog.TabIndex = 9;
        // 
        // colTime
        // 
        colTime.FillWeight = 10F;
        colTime.HeaderText = "Time";
        colTime.MinimumWidth = 8;
        colTime.Name = "colTime";
        colTime.ReadOnly = true;
        // 
        // colIp
        // 
        colIp.FillWeight = 15F;
        colIp.HeaderText = "Client IP";
        colIp.MinimumWidth = 8;
        colIp.Name = "colIp";
        colIp.ReadOnly = true;
        // 
        // colUser
        // 
        colUser.FillWeight = 12F;
        colUser.HeaderText = "User";
        colUser.MinimumWidth = 8;
        colUser.Name = "colUser";
        colUser.ReadOnly = true;
        // 
        // colMethod
        // 
        colMethod.FillWeight = 8F;
        colMethod.HeaderText = "Method";
        colMethod.MinimumWidth = 8;
        colMethod.Name = "colMethod";
        colMethod.ReadOnly = true;
        // 
        // colPath
        // 
        colPath.FillWeight = 40F;
        colPath.HeaderText = "Path";
        colPath.MinimumWidth = 8;
        colPath.Name = "colPath";
        colPath.ReadOnly = true;
        // 
        // colStatus
        // 
        colStatus.FillWeight = 8F;
        colStatus.HeaderText = "Status";
        colStatus.MinimumWidth = 8;
        colStatus.Name = "colStatus";
        colStatus.ReadOnly = true;
        // 
        // statusStrip
        // 
        statusStrip.ImageScalingSize = new Size(24, 24);
        statusStrip.Items.AddRange(new ToolStripItem[] { toolStripStatus });
        statusStrip.Location = new Point(0, 935);
        statusStrip.Name = "statusStrip";
        statusStrip.Padding = new Padding(1, 0, 20, 0);
        statusStrip.Size = new Size(1224, 32);
        statusStrip.TabIndex = 10;
        statusStrip.Text = "statusStrip";
        // 
        // toolStripStatus
        // 
        toolStripStatus.Name = "toolStripStatus";
        toolStripStatus.Size = new Size(106, 25);
        toolStripStatus.Text = "pc-ify ready";
        // 
        // lblConnectLabel
        // 
        lblConnectLabel.AutoSize = true;
        lblConnectLabel.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
        lblConnectLabel.Location = new Point(245, 92);
        lblConnectLabel.Name = "lblConnectLabel";
        lblConnectLabel.Size = new Size(109, 25);
        lblConnectLabel.TabIndex = 11;
        lblConnectLabel.Text = "Connect at:";
        // 
        // lblConnectAddress
        // 
        lblConnectAddress.AutoSize = true;
        lblConnectAddress.Font = new Font("Segoe UI", 9F);
        lblConnectAddress.ForeColor = Color.FromArgb(100, 180, 255);
        lblConnectAddress.Location = new Point(360, 92);
        lblConnectAddress.Name = "lblConnectAddress";
        lblConnectAddress.Size = new Size(190, 25);
        lblConnectAddress.TabIndex = 12;
        lblConnectAddress.Text = "— (server not running)";
        // 
        // btnCopyAddress
        // 
        btnCopyAddress.Anchor = AnchorStyles.Top | AnchorStyles.Right;
        btnCopyAddress.FlatStyle = FlatStyle.Flat;
        btnCopyAddress.Location = new Point(1101, 85);
        btnCopyAddress.Name = "btnCopyAddress";
        btnCopyAddress.Size = new Size(106, 39);
        btnCopyAddress.TabIndex = 13;
        btnCopyAddress.Text = "Copy";
        btnCopyAddress.UseVisualStyleBackColor = true;
        btnCopyAddress.Visible = false;
        btnCopyAddress.Click += btnCopyAddress_Click;
        // 
        // MainForm
        // 
        AutoScaleDimensions = new SizeF(10F, 25F);
        AutoScaleMode = AutoScaleMode.Font;
        ClientSize = new Size(1224, 967);
        Controls.Add(dgvLog);
        Controls.Add(btnCopyAddress);
        Controls.Add(lblConnectLabel);
        Controls.Add(btnClearLog);
        Controls.Add(btnThemeToggle);
        Controls.Add(btnSettings);
        Controls.Add(btnStartStop);
        Controls.Add(lblPort);
        Controls.Add(lblPortLabel);
        Controls.Add(lblStatus);
        Controls.Add(lblStatusLabel);
        Controls.Add(lblTitle);
        Controls.Add(statusStrip);
        Controls.Add(lblConnectAddress);
        DoubleBuffered = true;
        Margin = new Padding(4, 5, 4, 5);
        MinimumSize = new Size(991, 763);
        Name = "MainForm";
        StartPosition = FormStartPosition.CenterScreen;
        Text = "pc-ify Server";
        ((System.ComponentModel.ISupportInitialize)dgvLog).EndInit();
        statusStrip.ResumeLayout(false);
        statusStrip.PerformLayout();
        ResumeLayout(false);
        PerformLayout();
    }
}
