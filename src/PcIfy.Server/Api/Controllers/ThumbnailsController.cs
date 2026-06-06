using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PcIfy.Server.Services.Interfaces;
using PcIfy.Server.Constants;

namespace PcIfy.Server.Api.Controllers;

[ApiController]
[Authorize]
public class ThumbnailsController : ControllerBase
{
    private readonly IThumbnailService _thumbnails;
    private readonly IFileService _files;

    public ThumbnailsController(IThumbnailService thumbnails, IFileService files)
    {
        _thumbnails = thumbnails;
        _files = files;
    }

    [HttpGet(ApiRoutes.Thumbnails + "/{*filePath}")]
    public async Task<IActionResult> GetThumbnail(
        string filePath,
        [FromQuery] int? quality,
        [FromQuery] string size = "medium",
        [FromQuery] double? t = null)
    {
        var fullPath = Uri.UnescapeDataString(filePath.Replace('/', Path.DirectorySeparatorChar));
        if (!System.IO.Path.IsPathRooted(fullPath))
            fullPath = System.IO.Path.DirectorySeparatorChar + fullPath;

        var username = User.Identity?.Name ?? string.Empty;
        if (!_files.IsPathAllowed(fullPath, username)) return StatusCode(403, "Access denied.");
        if (!System.IO.File.Exists(fullPath)) return NotFound();

        string? thumbPath;

        if (quality.HasValue)
        {
            thumbPath = await _thumbnails.GetOrCreateThumbnailAsync(fullPath, quality.Value, t);
        }
        else
        {
            // Legacy size-based fallback for old clients
            var thumbSize = size.ToLowerInvariant() switch
            {
                "small" => ThumbnailSize.Small,
                "large" => ThumbnailSize.Large,
                _       => ThumbnailSize.Medium
            };
            thumbPath = await _thumbnails.GetOrCreateThumbnailAsync(fullPath, thumbSize);
        }

        if (thumbPath is null) return NotFound();
        return PhysicalFile(thumbPath, "image/jpeg");
    }
}
