using PcIfy.Client.ViewModels;

namespace PcIfy.Client.Views.Browser;

public partial class ImagePickerPage : ContentPage
{
    public ImagePickerPage(ImagePickerViewModel vm)
    {
        InitializeComponent();
        BindingContext = vm;
    }
}
