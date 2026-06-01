using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PcIfy.Server.Helpers;
using PcIfy.Server.Services.Interfaces;
using PcIfy.Server.Constants;

namespace PcIfy.Server.Api.Controllers;

[ApiController]
[Authorize]
public class FilesController : ControllerBase
{
    private readonly IFileService _files;

    public FilesController(IFileService files) => _files = files;

    private string CurrentUsername => User.Identity?.Name ?? string.Empty;

    [HttpGet(ApiRoutes.FilesRoots)]
    public IActionResult GetRoots() =>
        Ok(_files.GetConfiguredRoots(CurrentUsername).Select(r => new { path = r, displayName = Path.GetFileName(r) ?? r }));

    [HttpGet(ApiRoutes.FilesList)]
    public async Task<IActionResult> List([FromQuery] string path)
    {
        if (string.IsNullOrWhiteSpace(path)) return BadRequest("path is required.");
        if (!_files.IsPathAllowed(path, CurrentUsername)) return StatusCode(403, "Access denied.");

        try
        {
            var listing = await _files.GetFolderListingAsync(path);
            return Ok(listing);
        }
        catch (DirectoryNotFoundException)
        {
            return NotFound();
        }
    }

    [HttpGet(ApiRoutes.FilesStream + "/{*filePath}")]
    public async Task<IActionResult> Stream(string filePath)
    {
        var fullPath = Uri.UnescapeDataString(filePath.Replace('/', Path.DirectorySeparatorChar));
        if (!System.IO.Path.IsPathRooted(fullPath))
            fullPath = System.IO.Path.DirectorySeparatorChar + fullPath;

        if (!_files.IsPathAllowed(fullPath, CurrentUsername)) return StatusCode(403, "Access denied.");
        if (!System.IO.File.Exists(fullPath)) return NotFound();

        var info = _files.GetFileInfo(fullPath);
        var mimeType = MediaTypes.GetMimeType(info.Extension);
        var rangeHeader = Request.Headers["Range"].FirstOrDefault();
        var range = RangeRequestHelper.ParseRange(rangeHeader, info.Length);

        var fileStream = await _files.OpenFileStreamAsync(fullPath);

        if (range is not null)
        {
            RangeRequestHelper.SetPartialContentHeaders(Response, range, mimeType);
            fileStream.Seek(range.Start, SeekOrigin.Begin);
            return new FileStreamResult(fileStream, mimeType)
            {
                EnableRangeProcessing = false
            };
        }

        Response.Headers["Accept-Ranges"] = "bytes";
        return File(fileStream, mimeType, enableRangeProcessing: true);
    }

    [HttpGet(ApiRoutes.FilesDownload + "/{*filePath}")]
    public async Task<IActionResult> Download(string filePath)
    {
        var fullPath = Uri.UnescapeDataString(filePath.Replace('/', Path.DirectorySeparatorChar));
        if (!System.IO.Path.IsPathRooted(fullPath))
            fullPath = System.IO.Path.DirectorySeparatorChar + fullPath;

        if (!_files.IsPathAllowed(fullPath, CurrentUsername)) return StatusCode(403, "Access denied.");
        if (!System.IO.File.Exists(fullPath)) return NotFound();

        var info = _files.GetFileInfo(fullPath);
        var mimeType = MediaTypes.GetMimeType(info.Extension);
        var stream = await _files.OpenFileStreamAsync(fullPath);

        return File(stream, mimeType, info.Name);
    }
}
