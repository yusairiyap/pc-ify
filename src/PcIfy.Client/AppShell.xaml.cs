using PcIfy.Client.Views.Browser;
using PcIfy.Client.Views.Viewer;

namespace PcIfy.Client;

public partial class AppShell : Shell
{
    public AppShell()
    {
        InitializeComponent();

        Routing.RegisterRoute("browser",      typeof(BrowserPage));
        Routing.RegisterRoute("videoplayer",  typeof(VideoPlayerPage));
        Routing.RegisterRoute("imagegallery", typeof(ImageGalleryPage));
        Routing.RegisterRoute("imagepicker",  typeof(ImagePickerPage));
    }
}
