using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PcIfy.Server.DTOs.Files;
using PcIfy.Server.Helpers;
using PcIfy.Server.Services.Interfaces;
using PcIfy.Server.Constants;

namespace PcIfy.Server.Api.Controllers;

[ApiController]
[Authorize]
public class FilesController : ControllerBase
{
    private readonly IFileService _files;
    private readonly IThumbnailService _thumbnails;

    public FilesController(IFileService files, IThumbnailService thumbnails)
    {
        _files = files;
        _thumbnails = thumbnails;
    }

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

    [HttpGet(ApiRoutes.FilesVideoInfo)]
    public async Task<IActionResult> GetVideoInfo([FromQuery] string path)
    {
        if (string.IsNullOrWhiteSpace(path)) return BadRequest("path is required.");
        if (!_files.IsPathAllowed(path, CurrentUsername)) return StatusCode(403, "Access denied.");
        if (!System.IO.File.Exists(path)) return NotFound();

        var durationMs = await _thumbnails.GetVideoDurationMsAsync(path);
        return Ok(new { durationMs = durationMs ?? 0 });
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

    [HttpPost(ApiRoutes.FilesUpload)]
    [DisableRequestSizeLimit]
    public async Task<IActionResult> Upload([FromQuery] string path, [FromQuery] string filename)
    {
        if (string.IsNullOrWhiteSpace(path) || string.IsNullOrWhiteSpace(filename))
            return BadRequest("path and filename are required.");

        if (!_files.IsPathAllowed(path, CurrentUsername)) return StatusCode(403, "Access denied.");

        var destPath = System.IO.Path.Combine(path, filename);
        if (!_files.IsPathAllowed(destPath, CurrentUsername)) return StatusCode(403, "Access denied.");

        try
        {
            await using var fs = System.IO.File.Create(destPath);
            await Request.Body.CopyToAsync(fs);
            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, ex.Message);
        }
    }

    [HttpDelete(ApiRoutes.FilesDelete)]
    public IActionResult Delete([FromQuery] string path)
    {
        if (string.IsNullOrWhiteSpace(path)) return BadRequest("path is required.");
        if (!_files.IsPathAllowed(path, CurrentUsername)) return StatusCode(403, "Access denied.");

        try
        {
            if (System.IO.File.Exists(path))
                System.IO.File.Delete(path);
            else if (Directory.Exists(path))
                Directory.Delete(path, recursive: true);
            else
                return NotFound();

            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPost(ApiRoutes.FilesCopy)]
    public IActionResult Copy([FromBody] FileCopyMoveRequest body)
    {
        if (!_files.IsPathAllowed(body.Src, CurrentUsername)) return StatusCode(403, "Access denied.");
        if (!_files.IsPathAllowed(body.DestFolder, CurrentUsername)) return StatusCode(403, "Access denied.");

        try
        {
            var destPath = System.IO.Path.Combine(body.DestFolder, System.IO.Path.GetFileName(body.Src));
            if (System.IO.File.Exists(body.Src))
            {
                System.IO.File.Copy(body.Src, destPath, overwrite: true);
            }
            else if (Directory.Exists(body.Src))
            {
                CopyDirectory(body.Src, destPath);
            }
            else
            {
                return NotFound();
            }

            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPost(ApiRoutes.FilesMove)]
    public IActionResult Move([FromBody] FileCopyMoveRequest body)
    {
        if (!_files.IsPathAllowed(body.Src, CurrentUsername)) return StatusCode(403, "Access denied.");
        if (!_files.IsPathAllowed(body.DestFolder, CurrentUsername)) return StatusCode(403, "Access denied.");

        try
        {
            var destPath = System.IO.Path.Combine(body.DestFolder, System.IO.Path.GetFileName(body.Src));
            if (System.IO.File.Exists(body.Src))
            {
                System.IO.File.Move(body.Src, destPath, overwrite: true);
            }
            else if (Directory.Exists(body.Src))
            {
                try
                {
                    Directory.Move(body.Src, destPath);
                }
                catch (IOException)
                {
                    CopyDirectory(body.Src, destPath);
                    Directory.Delete(body.Src, recursive: true);
                }
            }
            else
            {
                return NotFound();
            }

            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            return StatusCode(500, ex.Message);
        }
    }

    private static void CopyDirectory(string src, string dest)
    {
        Directory.CreateDirectory(dest);
        foreach (var file in Directory.GetFiles(src))
            System.IO.File.Copy(file, System.IO.Path.Combine(dest, System.IO.Path.GetFileName(file)), overwrite: true);
        foreach (var dir in Directory.GetDirectories(src))
            CopyDirectory(dir, System.IO.Path.Combine(dest, System.IO.Path.GetFileName(dir)));
    }
}
