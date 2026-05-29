using PcIfy.Client.ViewModels;

namespace PcIfy.Client.Views.Viewer;

public partial class VideoPlayerPage : ContentPage
{
    public VideoPlayerPage(VideoPlayerViewModel vm)
    {
        InitializeComponent();
        BindingContext = vm;
    }
}
