namespace PcIfy.Server.Forms;

public partial class AddUserDialog : Form
{
    public string Username => txtUsername.Text.Trim();
    public string Password => txtPassword.Text;

    public AddUserDialog()
    {
        InitializeComponent();
    }
}
