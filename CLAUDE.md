# CLAUDE.md — pc-ify Developer Guide

## Project Overview

**pc-ify** is a local-network home entertainment system:
- **PcIfy.Server** — .NET 10 WinForms app that embeds an ASP.NET Core (Kestrel) API to serve files on the local network
- **PcIfy.Client** — Flutter app (Android + iOS) for browsing and streaming those files
- **PcIfy.Shared** — Class library with shared DTOs, constants, and models

## Solution Layout

```
src/
├── PcIfy.Shared/          DTOs, API route constants, MIME helpers
├── PcIfy.Server/          WinForms host + Kestrel API
└── PcIfy.Client/  Flutter mobile client
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
cd src/PcIfy.Client
flutter run
```

Or use VS Code with an Android emulator / physical device. The `launch.json` at repo root includes a ready-to-use Flutter launch config.

## FFmpeg (server thumbnail generation)

FFmpeg is **auto-downloaded on first launch** via `FFmpegSetupService`. On startup, if `ffmpeg.exe` is not found next to the exe, the user is prompted to download it (~30 MB from GitHub BtbN builds). A progress dialog shows download and extraction status.

Binaries land in `<exe-dir>/ffmpeg/ffmpeg.exe` and `ffprobe.exe`. `FFmpegSetupService.Configure()` is called at startup and again when `ThumbnailService` initialises.

To skip auto-download, the user can manually place the binaries at:
```
<server-exe-dir>/ffmpeg/ffmpeg.exe
<server-exe-dir>/ffmpeg/ffprobe.exe
```

## Architecture Patterns

### Service Interface Pattern (Server)

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

Flutter's `media_kit` video player and `CachedNetworkImage` set URLs directly; they cannot inject `Authorization` headers. Streaming and thumbnail endpoints therefore also accept the JWT via `?token=<jwt>` query parameter. This is configured in `JwtHelper.ConfigureJwtBearerOptions` via `OnMessageReceived`. Only streaming/thumbnail routes accept query-param tokens; all other endpoints require the `Authorization: Bearer` header.

**Do not remove this pattern** — it is required for video and image loading to work.

### PathSanitizer (Security)

Every file request on the server side must pass through `PathSanitizer.IsPathAllowed()` before any file system access. This prevents path traversal attacks. The check is in `FilesController` and `ThumbnailsController`. **Never skip this check.**

### Flutter State Management (Riverpod)

State is managed with `flutter_riverpod`. Providers live in `lib/providers/`. Services are exposed as `Provider<T>` (singleton); screen state uses `StateNotifierProvider` or `AsyncNotifierProvider`.

Navigation uses `go_router` configured in `lib/router.dart`. Pass data via route parameters or `extra`.

### Dark / Light Mode

**Server:** `Program.ApplyColorMode(string mode)` calls `Application.SetColorMode()`. The mode is stored in `AppSettings.ColorMode` (`"Dark"`, `"Light"`, `"System"`). It can be toggled at runtime from MainForm or the system tray.

**Client:** `ThemeService` in `lib/services/theme_service.dart` stores theme and accent color in `SharedPreferences`. The Riverpod theme provider notifies the app root to rebuild with the new `ThemeData`.

## Adding New API Endpoints

1. Add the route constant to `PcIfy.Shared/Constants/ApiRoutes.cs`
2. Add the controller method in `PcIfy.Server/Api/Controllers/`
3. Add the corresponding call to `ApiService` in `lib/services/api_service.dart`
4. If the endpoint streams a file, add it to the `StreamingPathPrefixes` array in `JwtHelper.cs`

## Adding New Client Screens

1. Create `lib/features/your_feature/your_screen.dart`
2. Add a route in `lib/router.dart`
3. Add any new services/providers under `lib/services/` and `lib/providers/`

## Key Files Quick Reference

| File | Purpose |
|---|---|
| `PcIfy.Shared/Constants/ApiRoutes.cs` | All API route strings |
| `PcIfy.Server/Program.cs` | Server entry point, DI root, color mode |
| `PcIfy.Server/Services/KestrelHostService.cs` | Embeds Kestrel in WinForms process |
| `PcIfy.Server/Helpers/PathSanitizer.cs` | Security — path traversal prevention |
| `PcIfy.Server/Helpers/JwtHelper.cs` | JWT generation + query-param support |
| `PcIfy.Client/lib/main.dart` | Flutter entry point |
| `PcIfy.Client/lib/router.dart` | go_router navigation config |
| `PcIfy.Client/lib/services/api_service.dart` | All HTTP calls to server |
| `PcIfy.Client/lib/services/auth_token_service.dart` | JWT storage and retrieval |
| `PcIfy.Client/lib/services/theme_service.dart` | Dark/light + accent color |
| `PcIfy.Client/lib/providers/` | Riverpod provider definitions |
