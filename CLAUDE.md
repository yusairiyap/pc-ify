# CLAUDE.md — pc-ify Developer Guide

## Project Overview

**pc-ify** is a local-network home entertainment system:
- **PcIfy.Server** — .NET 10 WinForms app that embeds an ASP.NET Core (Kestrel) API to serve files on the local network
- **PcIfy.Client** — .NET MAUI .NET 10 app (Android + iOS) for browsing and streaming those files
- **PcIfy.Shared** — Class library with shared DTOs, constants, and models

## Solution Layout

```
src/
├── PcIfy.Shared/          DTOs, API route constants, MIME helpers
├── PcIfy.Server/          WinForms host + Kestrel API
└── PcIfy.Client/          MAUI mobile client
```

## Running the Server

```bash
dotnet run --project src/PcIfy.Server
```

Or open `pc-ify.sln` in Visual Studio and run `PcIfy.Server`.

On first run, open Settings → Directories, add a source folder. The default credentials are `admin` / `admin` — change them in Settings → Users.

The server settings are stored at `%APPDATA%\pcify\settings.json`.

## Running the Client (Android)

```bash
dotnet build src/PcIfy.Client -f net10.0-android -t:Run
```

Or use Visual Studio with an Android emulator / physical device.

## FFmpeg (server thumbnail generation)

FFmpeg is **auto-downloaded on first launch** via `FFmpegSetupService`. On startup, if `ffmpeg.exe` is not found next to the exe, the user is prompted to download it (~30 MB from GitHub BtbN builds). A progress dialog shows download and extraction status.

Binaries land in `<exe-dir>/ffmpeg/ffmpeg.exe` and `ffprobe.exe`. `FFmpegSetupService.Configure()` is called at startup and again when `ThumbnailService` initialises.

To skip auto-download, the user can manually place the binaries at:
```
<server-exe-dir>/ffmpeg/ffmpeg.exe
<server-exe-dir>/ffmpeg/ffprobe.exe
```

## Architecture Patterns

### Service Interface Pattern

Always inject interfaces, never concrete types. Every service has an interface in `Services/Interfaces/`. This keeps code testable and the DI container swappable.

```csharp
// Correct
public class SomeClass(IFileService files) { ... }

// Wrong
public class SomeClass(FileService files) { ... }
```

### WinForms + Kestrel Threading

Kestrel runs on a background thread; WinForms runs on the STA UI thread. When updating WinForms controls from Kestrel callbacks always use `form.Invoke()`:

```csharp
if (InvokeRequired)
    Invoke(() => UpdateLabel(text));
else
    UpdateLabel(text);
```

`IConnectionLogService` is shared between both threads and is thread-safe (`ConcurrentQueue`).

### JWT Query Parameter for Streaming

`MediaElement` and `<Image>` in MAUI set URI sources directly; they cannot inject `Authorization` headers. Streaming and thumbnail endpoints therefore also accept the JWT via `?token=<jwt>` query parameter. This is configured in `JwtHelper.ConfigureJwtBearerOptions` via `OnMessageReceived`. Only streaming/thumbnail routes accept query-param tokens; all other endpoints require the `Authorization: Bearer` header.

**Do not remove this pattern** — it is required for video and image loading to work.

### PathSanitizer (Security)

Every file request on the server side must pass through `PathSanitizer.IsPathAllowed()` before any file system access. This prevents path traversal attacks. The check is in `FilesController` and `ThumbnailsController`. **Never skip this check.**

### MAUI DI and Navigation

DI is configured in `MauiProgram.cs`. ViewModels are `Transient` (created fresh per navigation), except `SettingsViewModel` which is `Singleton`.

Navigate using Shell routes:
```csharp
await Shell.Current.GoToAsync($"browser?path={Uri.EscapeDataString(path)}");
```

Query properties are received via `[QueryProperty]` on ViewModels.

### Dark / Light Mode

**Server:** `Program.ApplyColorMode(string mode)` calls `Application.SetColorMode()`. The mode is stored in `AppSettings.ColorMode` (`"Dark"`, `"Light"`, `"System"`). It can be toggled at runtime from MainForm or the system tray.

**Client:** `IThemeService.Apply(AppTheme, Color)` sets `Application.Current.UserAppTheme`. All XAML colours use `AppThemeBinding` so they update immediately without page reload. Persisted in `Preferences`.

## Adding New API Endpoints

1. Add the route constant to `PcIfy.Shared/Constants/ApiRoutes.cs`
2. Add the controller method in `PcIfy.Server/Api/Controllers/`
3. Add the corresponding typed call to `IApiService` + `ApiService.cs` in the client
4. If the endpoint streams a file, add it to the `StreamingPathPrefixes` array in `JwtHelper.cs`

## Adding New Client Screens

1. Create `Views/YourFeature/YourPage.xaml` + `.cs`
2. Create `ViewModels/YourViewModel.cs` (extend `BaseViewModel`)
3. Register both in `MauiProgram.cs` (transient)
4. Register the route in `AppShell.xaml.cs`

## Key Files Quick Reference

| File | Purpose |
|---|---|
| `PcIfy.Shared/Constants/ApiRoutes.cs` | All API route strings |
| `PcIfy.Server/Program.cs` | Server entry point, DI root, color mode |
| `PcIfy.Server/Services/KestrelHostService.cs` | Embeds Kestrel in WinForms process |
| `PcIfy.Server/Helpers/PathSanitizer.cs` | Security — path traversal prevention |
| `PcIfy.Server/Helpers/JwtHelper.cs` | JWT generation + query-param support |
| `PcIfy.Client/MauiProgram.cs` | Client DI registration |
| `PcIfy.Client/Services/ApiService.cs` | All HTTP calls to server |
| `PcIfy.Client/Services/AuthorizationHeaderHandler.cs` | Auto-attaches JWT to every request |
| `PcIfy.Client/Services/ThemeService.cs` | Dark/light + accent color |
