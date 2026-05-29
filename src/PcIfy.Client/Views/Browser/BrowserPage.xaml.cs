using PcIfy.Client.ViewModels;

namespace PcIfy.Client.Views.Browser;

public partial class BrowserPage : ContentPage
{
    private readonly BrowserViewModel _vm;

    public BrowserPage(BrowserViewModel vm)
    {
        InitializeComponent();
        BindingContext = _vm = vm;
    }

    protected override async void OnAppearing()
    {
        base.OnAppearing();
        _vm.UpdateLayout(Width > 0 ? Width : DeviceDisplay.MainDisplayInfo.Width / DeviceDisplay.MainDisplayInfo.Density);

        if (string.IsNullOrEmpty(_vm.CurrentPath))
            await _vm.LoadRootsAsync();
    }

    protected override void OnSizeAllocated(double width, double height)
    {
        base.OnSizeAllocated(width, height);
        if (width > 0)
            _vm.UpdateLayout(width);
    }
}
