namespace PcIfy.Client.Helpers;

public static class ImageCropHelper
{
    public record CropRect(double X, double Y, double Width, double Height);

    public static CropRect ComputeSourceRect(
        double imageWidth, double imageHeight,
        double viewWidth, double viewHeight,
        float cropX, float cropY, float cropW, float cropH, float zoom)
    {
        var scaledW = imageWidth * zoom;
        var scaledH = imageHeight * zoom;

        var sx = cropX * scaledW;
        var sy = cropY * scaledH;
        var sw = Math.Min(cropW * scaledW, scaledW - sx);
        var sh = Math.Min(cropH * scaledH, scaledH - sy);

        return new CropRect(sx, sy, sw, sh);
    }
}
