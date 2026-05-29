using PcIfy.Client.ViewModels;

namespace PcIfy.Client.Views.Setup;

public partial class SetupPage : ContentPage
{
    public SetupPage(SetupViewModel vm)
    {
        InitializeComponent();
        BindingContext = vm;
    }
}
