using PcIfy.Client.ViewModels;

namespace PcIfy.Client.Views.Viewer;

public partial class ImageGalleryPage : ContentPage
{
    public ImageGalleryPage(ImageGalleryViewModel vm)
    {
        InitializeComponent();
        BindingContext = vm;
    }
}
