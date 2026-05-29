using Microsoft.AspNetCore.Http;

namespace PcIfy.Server.Helpers;

public static class RangeRequestHelper
{
    public record RangeInfo(long Start, long End, long TotalLength);

    public static RangeInfo? ParseRange(string? rangeHeader, long totalLength)
    {
        if (string.IsNullOrEmpty(rangeHeader) || !rangeHeader.StartsWith("bytes="))
            return null;

        var range = rangeHeader["bytes=".Length..];
        var parts = range.Split('-');
        if (parts.Length != 2) return null;

        long start = string.IsNullOrEmpty(parts[0]) ? 0 : long.Parse(parts[0]);
        long end = string.IsNullOrEmpty(parts[1]) ? totalLength - 1 : long.Parse(parts[1]);

        end = Math.Min(end, totalLength - 1);
        if (start > end) return null;

        return new RangeInfo(start, end, totalLength);
    }

    public static void SetPartialContentHeaders(HttpResponse response, RangeInfo range, string contentType)
    {
        response.StatusCode = 206;
        response.ContentType = contentType;
        response.Headers["Content-Range"] = $"bytes {range.Start}-{range.End}/{range.TotalLength}";
        response.Headers["Accept-Ranges"] = "bytes";
        response.ContentLength = range.End - range.Start + 1;
    }
}
