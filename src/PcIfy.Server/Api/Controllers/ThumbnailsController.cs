using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PcIfy.Server.Services.Interfaces;
using PcIfy.Shared.Constants;

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
    public async Task<IActionResult> GetThumbnail(string filePath, [FromQuery] string size = "medium")
    {
        var fullPath = Uri.UnescapeDataString(filePath.Replace('/', Path.DirectorySeparatorChar));
        if (!System.IO.Path.IsPathRooted(fullPath))
            fullPath = System.IO.Path.DirectorySeparatorChar + fullPath;

        if (!_files.IsPathAllowed(fullPath)) return StatusCode(403, "Access denied.");
        if (!System.IO.File.Exists(fullPath)) return NotFound();

        var thumbSize = size.ToLowerInvariant() switch
        {
            "small"  => ThumbnailSize.Small,
            "large"  => ThumbnailSize.Large,
            _        => ThumbnailSize.Medium
        };

        var thumbPath = await _thumbnails.GetOrCreateThumbnailAsync(fullPath, thumbSize);
        if (thumbPath is null) return NotFound();

        return PhysicalFile(thumbPath, "image/jpeg");
    }
}
