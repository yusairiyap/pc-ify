using PcIfy.Client.Services.Interfaces;

namespace PcIfy.Client.Services;

public class ExternalPlayerService : IExternalPlayerService
{
    public Task<bool> CanOpenExternallyAsync(string mimeType)
    {
#if ANDROID
        try
        {
            var intent = new Android.Content.Intent(Android.Content.Intent.ActionView);
            intent.SetDataAndType(Android.Net.Uri.Parse("http://example.com/test.mp4"), mimeType);
            intent.AddFlags(Android.Content.ActivityFlags.NewTask);
            var ctx = Android.App.Application.Context;
            var activities = ctx.PackageManager?.QueryIntentActivities(
                intent, Android.Content.PM.PackageInfoFlags.MatchDefaultOnly);
            return Task.FromResult(activities?.Count > 0);
        }
        catch { return Task.FromResult(false); }
#elif IOS
        return Task.FromResult(mimeType.StartsWith("video/") || mimeType.StartsWith("audio/"));
#elif WINDOWS
        return Task.FromResult(mimeType.StartsWith("video/") || mimeType.StartsWith("audio/"));
#else
        return Task.FromResult(false);
#endif
    }

    public Task OpenAsync(System.Uri streamUri, string mimeType, string title)
    {
#if ANDROID
        var ctx = Android.App.Application.Context;
        var intent = new Android.Content.Intent(Android.Content.Intent.ActionView);
        intent.SetDataAndType(Android.Net.Uri.Parse(streamUri.ToString()), mimeType);
        intent.PutExtra("title", title);
        intent.AddFlags(Android.Content.ActivityFlags.NewTask);
        ctx.StartActivity(intent);
        return Task.CompletedTask;
#elif IOS
        var vlcUri = new System.Uri($"vlc://{streamUri.Host}{streamUri.PathAndQuery}");
        var nsVlc = new Foundation.NSUrl(vlcUri.ToString());
        if (UIKit.UIApplication.SharedApplication.CanOpenUrl(nsVlc))
            UIKit.UIApplication.SharedApplication.OpenUrl(nsVlc, new UIKit.UIApplicationOpenUrlOptions(), null);
        else
            UIKit.UIApplication.SharedApplication.OpenUrl(
                new Foundation.NSUrl(streamUri.ToString()), new UIKit.UIApplicationOpenUrlOptions(), null);
        return Task.CompletedTask;
#elif WINDOWS
        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(streamUri.ToString()) { UseShellExecute = true });
        return Task.CompletedTask;
#else
        return Task.CompletedTask;
#endif
    }
}
