namespace PcIfy.Server.Forms;

partial class AddUserDialog
{
    private System.ComponentModel.IContainer components = null;

    private System.Windows.Forms.Label lblUser;
    private System.Windows.Forms.TextBox txtUsername;
    private System.Windows.Forms.Label lblPass;
    private System.Windows.Forms.TextBox txtPassword;
    private System.Windows.Forms.Button btnOk;
    private System.Windows.Forms.Button btnCancel;

    protected override void Dispose(bool disposing)
    {
        if (disposing && (components != null))
            components.Dispose();
        base.Dispose(disposing);
    }

    private void InitializeComponent()
    {
        this.components = new System.ComponentModel.Container();
        this.lblUser = new System.Windows.Forms.Label();
        this.txtUsername = new System.Windows.Forms.TextBox();
        this.lblPass = new System.Windows.Forms.Label();
        this.txtPassword = new System.Windows.Forms.TextBox();
        this.btnOk = new System.Windows.Forms.Button();
        this.btnCancel = new System.Windows.Forms.Button();
        this.SuspendLayout();
        //
        // lblUser
        //
        this.lblUser.AutoSize = true;
        this.lblUser.Location = new System.Drawing.Point(12, 18);
        this.lblUser.Name = "lblUser";
        this.lblUser.Size = new System.Drawing.Size(60, 15);
        this.lblUser.TabIndex = 0;
        this.lblUser.Text = "Username:";
        //
        // txtUsername
        //
        this.txtUsername.Location = new System.Drawing.Point(110, 14);
        this.txtUsername.Name = "txtUsername";
        this.txtUsername.Size = new System.Drawing.Size(150, 23);
        this.txtUsername.TabIndex = 1;
        //
        // lblPass
        //
        this.lblPass.AutoSize = true;
        this.lblPass.Location = new System.Drawing.Point(12, 50);
        this.lblPass.Name = "lblPass";
        this.lblPass.Size = new System.Drawing.Size(57, 15);
        this.lblPass.TabIndex = 2;
        this.lblPass.Text = "Password:";
        //
        // txtPassword
        //
        this.txtPassword.Location = new System.Drawing.Point(110, 46);
        this.txtPassword.Name = "txtPassword";
        this.txtPassword.Size = new System.Drawing.Size(150, 23);
        this.txtPassword.TabIndex = 3;
        this.txtPassword.UseSystemPasswordChar = true;
        //
        // btnOk
        //
        this.btnOk.DialogResult = System.Windows.Forms.DialogResult.OK;
        this.btnOk.FlatStyle = System.Windows.Forms.FlatStyle.System;
        this.btnOk.Location = new System.Drawing.Point(110, 86);
        this.btnOk.Name = "btnOk";
        this.btnOk.Size = new System.Drawing.Size(70, 28);
        this.btnOk.TabIndex = 4;
        this.btnOk.Text = "OK";
        this.btnOk.UseVisualStyleBackColor = true;
        //
        // btnCancel
        //
        this.btnCancel.DialogResult = System.Windows.Forms.DialogResult.Cancel;
        this.btnCancel.FlatStyle = System.Windows.Forms.FlatStyle.System;
        this.btnCancel.Location = new System.Drawing.Point(188, 86);
        this.btnCancel.Name = "btnCancel";
        this.btnCancel.Size = new System.Drawing.Size(70, 28);
        this.btnCancel.TabIndex = 5;
        this.btnCancel.Text = "Cancel";
        this.btnCancel.UseVisualStyleBackColor = true;
        //
        // AddUserDialog
        //
        this.AcceptButton = this.btnOk;
        this.AutoScaleDimensions = new System.Drawing.SizeF(7F, 15F);
        this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
        this.CancelButton = this.btnCancel;
        this.ClientSize = new System.Drawing.Size(276, 130);
        this.Controls.Add(this.lblUser);
        this.Controls.Add(this.txtUsername);
        this.Controls.Add(this.lblPass);
        this.Controls.Add(this.txtPassword);
        this.Controls.Add(this.btnOk);
        this.Controls.Add(this.btnCancel);
        this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedDialog;
        this.MaximizeBox = false;
        this.MinimizeBox = false;
        this.Name = "AddUserDialog";
        this.StartPosition = System.Windows.Forms.FormStartPosition.CenterParent;
        this.Text = "Add User";
        this.ResumeLayout(false);
        this.PerformLayout();
    }
}
