namespace PcIfy.Server.Forms;

partial class SettingsForm
{
    private System.ComponentModel.IContainer components = null;

    private System.Windows.Forms.TabControl tabControl;
    private System.Windows.Forms.TabPage tabGeneral;
    private System.Windows.Forms.TabPage tabDirectories;
    private System.Windows.Forms.TabPage tabUsers;
    private System.Windows.Forms.Label lblPort;
    private System.Windows.Forms.NumericUpDown nudPort;
    private System.Windows.Forms.CheckBox chkAutoStart;
    private System.Windows.Forms.Label lblServerName;
    private System.Windows.Forms.TextBox txtServerName;
    private System.Windows.Forms.Label lblColorMode;
    private System.Windows.Forms.ComboBox cmbColorMode;
    private System.Windows.Forms.ListBox lstDirectories;
    private System.Windows.Forms.Button btnAddDir;
    private System.Windows.Forms.Button btnRemoveDir;
    private System.Windows.Forms.ListBox lstUsers;
    private System.Windows.Forms.Button btnAddUser;
    private System.Windows.Forms.Button btnRemoveUser;
    private System.Windows.Forms.GroupBox grpUserDirs;
    private System.Windows.Forms.CheckedListBox clbUserDirs;
    private System.Windows.Forms.Label lblUserDirsHint;
    private System.Windows.Forms.Button btnSave;
    private System.Windows.Forms.Button btnCancel;
    private System.Windows.Forms.Button btnExport;
    private System.Windows.Forms.Button btnImport;

    protected override void Dispose(bool disposing)
    {
        if (disposing && (components != null))
            components.Dispose();
        base.Dispose(disposing);
    }

    private void InitializeComponent()
    {
        this.components = new System.ComponentModel.Container();
        this.tabControl = new System.Windows.Forms.TabControl();
        this.tabGeneral = new System.Windows.Forms.TabPage();
        this.tabDirectories = new System.Windows.Forms.TabPage();
        this.tabUsers = new System.Windows.Forms.TabPage();
        this.lblPort = new System.Windows.Forms.Label();
        this.nudPort = new System.Windows.Forms.NumericUpDown();
        this.chkAutoStart = new System.Windows.Forms.CheckBox();
        this.lblServerName = new System.Windows.Forms.Label();
        this.txtServerName = new System.Windows.Forms.TextBox();
        this.lblColorMode = new System.Windows.Forms.Label();
        this.cmbColorMode = new System.Windows.Forms.ComboBox();
        this.lstDirectories = new System.Windows.Forms.ListBox();
        this.btnAddDir = new System.Windows.Forms.Button();
        this.btnRemoveDir = new System.Windows.Forms.Button();
        this.lstUsers = new System.Windows.Forms.ListBox();
        this.btnAddUser = new System.Windows.Forms.Button();
        this.btnRemoveUser = new System.Windows.Forms.Button();
        this.grpUserDirs = new System.Windows.Forms.GroupBox();
        this.clbUserDirs = new System.Windows.Forms.CheckedListBox();
        this.lblUserDirsHint = new System.Windows.Forms.Label();
        this.btnSave = new System.Windows.Forms.Button();
        this.btnCancel = new System.Windows.Forms.Button();
        this.btnExport = new System.Windows.Forms.Button();
        this.btnImport = new System.Windows.Forms.Button();
        this.tabControl.SuspendLayout();
        this.tabGeneral.SuspendLayout();
        this.tabDirectories.SuspendLayout();
        this.tabUsers.SuspendLayout();
        this.grpUserDirs.SuspendLayout();
        ((System.ComponentModel.ISupportInitialize)(this.nudPort)).BeginInit();
        this.SuspendLayout();
        //
        // lblPort
        //
        this.lblPort.AutoSize = true;
        this.lblPort.Location = new System.Drawing.Point(12, 18);
        this.lblPort.Name = "lblPort";
        this.lblPort.Size = new System.Drawing.Size(29, 15);
        this.lblPort.TabIndex = 0;
        this.lblPort.Text = "Port:";
        //
        // nudPort
        //
        this.nudPort.Location = new System.Drawing.Point(120, 14);
        this.nudPort.Maximum = new decimal(new int[] { 65535, 0, 0, 0 });
        this.nudPort.Minimum = new decimal(new int[] { 1024, 0, 0, 0 });
        this.nudPort.Name = "nudPort";
        this.nudPort.Size = new System.Drawing.Size(100, 23);
        this.nudPort.TabIndex = 1;
        this.nudPort.Value = new decimal(new int[] { 8080, 0, 0, 0 });
        //
        // chkAutoStart
        //
        this.chkAutoStart.AutoSize = true;
        this.chkAutoStart.Location = new System.Drawing.Point(12, 50);
        this.chkAutoStart.Name = "chkAutoStart";
        this.chkAutoStart.Size = new System.Drawing.Size(175, 19);
        this.chkAutoStart.TabIndex = 2;
        this.chkAutoStart.Text = "Auto-start server on launch";
        this.chkAutoStart.UseVisualStyleBackColor = true;
        //
        // lblServerName
        //
        this.lblServerName.AutoSize = true;
        this.lblServerName.Location = new System.Drawing.Point(12, 80);
        this.lblServerName.Name = "lblServerName";
        this.lblServerName.Size = new System.Drawing.Size(75, 15);
        this.lblServerName.TabIndex = 3;
        this.lblServerName.Text = "Server name:";
        //
        // txtServerName
        //
        this.txtServerName.Location = new System.Drawing.Point(120, 76);
        this.txtServerName.Name = "txtServerName";
        this.txtServerName.Size = new System.Drawing.Size(200, 23);
        this.txtServerName.TabIndex = 4;
        //
        // lblColorMode
        //
        this.lblColorMode.AutoSize = true;
        this.lblColorMode.Location = new System.Drawing.Point(12, 112);
        this.lblColorMode.Name = "lblColorMode";
        this.lblColorMode.Size = new System.Drawing.Size(68, 15);
        this.lblColorMode.TabIndex = 5;
        this.lblColorMode.Text = "Color mode:";
        //
        // cmbColorMode
        //
        this.cmbColorMode.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
        this.cmbColorMode.FormattingEnabled = true;
        this.cmbColorMode.Location = new System.Drawing.Point(120, 108);
        this.cmbColorMode.Name = "cmbColorMode";
        this.cmbColorMode.Size = new System.Drawing.Size(120, 23);
        this.cmbColorMode.TabIndex = 6;
        //
        // tabGeneral
        //
        this.tabGeneral.Controls.Add(this.lblPort);
        this.tabGeneral.Controls.Add(this.nudPort);
        this.tabGeneral.Controls.Add(this.chkAutoStart);
        this.tabGeneral.Controls.Add(this.lblServerName);
        this.tabGeneral.Controls.Add(this.txtServerName);
        this.tabGeneral.Controls.Add(this.lblColorMode);
        this.tabGeneral.Controls.Add(this.cmbColorMode);
        this.tabGeneral.Location = new System.Drawing.Point(4, 24);
        this.tabGeneral.Name = "tabGeneral";
        this.tabGeneral.Padding = new System.Windows.Forms.Padding(3);
        this.tabGeneral.Size = new System.Drawing.Size(440, 292);
        this.tabGeneral.TabIndex = 0;
        this.tabGeneral.Text = "General";
        this.tabGeneral.UseVisualStyleBackColor = false;
        this.tabGeneral.BackColor = System.Drawing.SystemColors.Control;
        //
        // lstDirectories
        //
        this.lstDirectories.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) | System.Windows.Forms.AnchorStyles.Left)));
        this.lstDirectories.FormattingEnabled = true;
        this.lstDirectories.ItemHeight = 15;
        this.lstDirectories.Location = new System.Drawing.Point(8, 8);
        this.lstDirectories.Name = "lstDirectories";
        this.lstDirectories.Size = new System.Drawing.Size(340, 244);
        this.lstDirectories.TabIndex = 0;
        //
        // btnAddDir
        //
        this.btnAddDir.FlatStyle = System.Windows.Forms.FlatStyle.System;
        this.btnAddDir.Location = new System.Drawing.Point(355, 8);
        this.btnAddDir.Name = "btnAddDir";
        this.btnAddDir.Size = new System.Drawing.Size(70, 28);
        this.btnAddDir.TabIndex = 1;
        this.btnAddDir.Text = "Add…";
        this.btnAddDir.UseVisualStyleBackColor = true;
        this.btnAddDir.Click += new System.EventHandler(this.btnAddDir_Click);
        //
        // btnRemoveDir
        //
        this.btnRemoveDir.FlatStyle = System.Windows.Forms.FlatStyle.System;
        this.btnRemoveDir.Location = new System.Drawing.Point(355, 42);
        this.btnRemoveDir.Name = "btnRemoveDir";
        this.btnRemoveDir.Size = new System.Drawing.Size(70, 28);
        this.btnRemoveDir.TabIndex = 2;
        this.btnRemoveDir.Text = "Remove";
        this.btnRemoveDir.UseVisualStyleBackColor = true;
        this.btnRemoveDir.Click += new System.EventHandler(this.btnRemoveDir_Click);
        //
        // tabDirectories
        //
        this.tabDirectories.Controls.Add(this.lstDirectories);
        this.tabDirectories.Controls.Add(this.btnAddDir);
        this.tabDirectories.Controls.Add(this.btnRemoveDir);
        this.tabDirectories.Location = new System.Drawing.Point(4, 24);
        this.tabDirectories.Name = "tabDirectories";
        this.tabDirectories.Padding = new System.Windows.Forms.Padding(3);
        this.tabDirectories.Size = new System.Drawing.Size(440, 292);
        this.tabDirectories.TabIndex = 1;
        this.tabDirectories.Text = "Directories";
        this.tabDirectories.UseVisualStyleBackColor = false;
        this.tabDirectories.BackColor = System.Drawing.SystemColors.Control;
        //
        // lstUsers
        //
        this.lstUsers.FormattingEnabled = true;
        this.lstUsers.ItemHeight = 15;
        this.lstUsers.Location = new System.Drawing.Point(8, 8);
        this.lstUsers.Name = "lstUsers";
        this.lstUsers.Size = new System.Drawing.Size(200, 244);
        this.lstUsers.TabIndex = 0;
        this.lstUsers.SelectedIndexChanged += new System.EventHandler(this.lstUsers_SelectedIndexChanged);
        //
        // btnAddUser
        //
        this.btnAddUser.FlatStyle = System.Windows.Forms.FlatStyle.System;
        this.btnAddUser.Location = new System.Drawing.Point(215, 8);
        this.btnAddUser.Name = "btnAddUser";
        this.btnAddUser.Size = new System.Drawing.Size(90, 28);
        this.btnAddUser.TabIndex = 1;
        this.btnAddUser.Text = "Add User…";
        this.btnAddUser.UseVisualStyleBackColor = true;
        this.btnAddUser.Click += new System.EventHandler(this.btnAddUser_Click);
        //
        // btnRemoveUser
        //
        this.btnRemoveUser.FlatStyle = System.Windows.Forms.FlatStyle.System;
        this.btnRemoveUser.Location = new System.Drawing.Point(215, 42);
        this.btnRemoveUser.Name = "btnRemoveUser";
        this.btnRemoveUser.Size = new System.Drawing.Size(90, 28);
        this.btnRemoveUser.TabIndex = 2;
        this.btnRemoveUser.Text = "Remove";
        this.btnRemoveUser.UseVisualStyleBackColor = true;
        this.btnRemoveUser.Click += new System.EventHandler(this.btnRemoveUser_Click);
        //
        // lblUserDirsHint
        //
        this.lblUserDirsHint.AutoSize = true;
        this.lblUserDirsHint.ForeColor = System.Drawing.SystemColors.GrayText;
        this.lblUserDirsHint.Location = new System.Drawing.Point(6, 162);
        this.lblUserDirsHint.Name = "lblUserDirsHint";
        this.lblUserDirsHint.Size = new System.Drawing.Size(135, 15);
        this.lblUserDirsHint.TabIndex = 1;
        this.lblUserDirsHint.Text = "Empty = unrestricted access";
        //
        // clbUserDirs
        //
        this.clbUserDirs.CheckOnClick = true;
        this.clbUserDirs.FormattingEnabled = true;
        this.clbUserDirs.Location = new System.Drawing.Point(6, 22);
        this.clbUserDirs.Name = "clbUserDirs";
        this.clbUserDirs.Size = new System.Drawing.Size(203, 136);
        this.clbUserDirs.TabIndex = 0;
        //
        // grpUserDirs
        //
        this.grpUserDirs.Controls.Add(this.clbUserDirs);
        this.grpUserDirs.Controls.Add(this.lblUserDirsHint);
        this.grpUserDirs.Location = new System.Drawing.Point(215, 78);
        this.grpUserDirs.Name = "grpUserDirs";
        this.grpUserDirs.Size = new System.Drawing.Size(215, 185);
        this.grpUserDirs.TabIndex = 3;
        this.grpUserDirs.TabStop = false;
        this.grpUserDirs.Text = "Directory Access";
        //
        // tabUsers
        //
        this.tabUsers.Controls.Add(this.lstUsers);
        this.tabUsers.Controls.Add(this.btnAddUser);
        this.tabUsers.Controls.Add(this.btnRemoveUser);
        this.tabUsers.Controls.Add(this.grpUserDirs);
        this.tabUsers.Location = new System.Drawing.Point(4, 24);
        this.tabUsers.Name = "tabUsers";
        this.tabUsers.Padding = new System.Windows.Forms.Padding(3);
        this.tabUsers.Size = new System.Drawing.Size(440, 292);
        this.tabUsers.TabIndex = 2;
        this.tabUsers.Text = "Users";
        this.tabUsers.UseVisualStyleBackColor = false;
        this.tabUsers.BackColor = System.Drawing.SystemColors.Control;
        //
        // tabControl
        //
        this.tabControl.Anchor = ((System.Windows.Forms.AnchorStyles)((((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Bottom) | System.Windows.Forms.AnchorStyles.Left) | System.Windows.Forms.AnchorStyles.Right)));
        this.tabControl.Controls.Add(this.tabGeneral);
        this.tabControl.Controls.Add(this.tabDirectories);
        this.tabControl.Controls.Add(this.tabUsers);
        this.tabControl.Location = new System.Drawing.Point(8, 8);
        this.tabControl.Name = "tabControl";
        this.tabControl.SelectedIndex = 0;
        this.tabControl.Size = new System.Drawing.Size(448, 320);
        this.tabControl.TabIndex = 0;
        //
        // btnExport
        //
        this.btnExport.FlatStyle = System.Windows.Forms.FlatStyle.System;
        this.btnExport.Location = new System.Drawing.Point(8, 340);
        this.btnExport.Name = "btnExport";
        this.btnExport.Size = new System.Drawing.Size(100, 30);
        this.btnExport.TabIndex = 3;
        this.btnExport.Text = "Export…";
        this.btnExport.UseVisualStyleBackColor = true;
        this.btnExport.Click += new System.EventHandler(this.btnExport_Click);
        //
        // btnImport
        //
        this.btnImport.FlatStyle = System.Windows.Forms.FlatStyle.System;
        this.btnImport.Location = new System.Drawing.Point(114, 340);
        this.btnImport.Name = "btnImport";
        this.btnImport.Size = new System.Drawing.Size(100, 30);
        this.btnImport.TabIndex = 4;
        this.btnImport.Text = "Import…";
        this.btnImport.UseVisualStyleBackColor = true;
        this.btnImport.Click += new System.EventHandler(this.btnImport_Click);
        //
        // btnSave
        //
        this.btnSave.FlatStyle = System.Windows.Forms.FlatStyle.System;
        this.btnSave.Location = new System.Drawing.Point(285, 340);
        this.btnSave.Name = "btnSave";
        this.btnSave.Size = new System.Drawing.Size(80, 30);
        this.btnSave.TabIndex = 1;
        this.btnSave.Text = "Save";
        this.btnSave.UseVisualStyleBackColor = true;
        this.btnSave.Click += new System.EventHandler(this.btnSave_Click);
        //
        // btnCancel
        //
        this.btnCancel.DialogResult = System.Windows.Forms.DialogResult.Cancel;
        this.btnCancel.FlatStyle = System.Windows.Forms.FlatStyle.System;
        this.btnCancel.Location = new System.Drawing.Point(373, 340);
        this.btnCancel.Name = "btnCancel";
        this.btnCancel.Size = new System.Drawing.Size(80, 30);
        this.btnCancel.TabIndex = 2;
        this.btnCancel.Text = "Cancel";
        this.btnCancel.UseVisualStyleBackColor = true;
        //
        // SettingsForm
        //
        this.AcceptButton = this.btnSave;
        this.AutoScaleDimensions = new System.Drawing.SizeF(7F, 15F);
        this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
        this.CancelButton = this.btnCancel;
        this.ClientSize = new System.Drawing.Size(464, 381);
        this.Controls.Add(this.tabControl);
        this.Controls.Add(this.btnSave);
        this.Controls.Add(this.btnCancel);
        this.Controls.Add(this.btnExport);
        this.Controls.Add(this.btnImport);
        this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedDialog;
        this.MaximizeBox = false;
        this.MinimizeBox = false;
        this.Name = "SettingsForm";
        this.StartPosition = System.Windows.Forms.FormStartPosition.CenterParent;
        this.Text = "Settings — pc-ify";
        this.tabControl.ResumeLayout(false);
        this.tabGeneral.ResumeLayout(false);
        this.tabGeneral.PerformLayout();
        this.tabDirectories.ResumeLayout(false);
        this.tabUsers.ResumeLayout(false);
        this.grpUserDirs.ResumeLayout(false);
        this.grpUserDirs.PerformLayout();
        ((System.ComponentModel.ISupportInitialize)(this.nudPort)).EndInit();
        this.ResumeLayout(false);
    }
}
