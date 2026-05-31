# CLAUDE.md — pc-ify Developer Guide

## Project Overview

**pc-ify** is a local-network home entertainment system:
- **PcIfy.Server.Flutter** — Flutter server app (Windows · Android · macOS) that embeds a `shelf`-based HTTP API to serve files on the local network
- **PcIfy.Client** — Flutter client app (Android · iOS · macOS · Windows) for browsing and streaming those files
- **PcIfy.Server** *(legacy)* — .NET 10 WinForms app kept for reference; still builds and runs independently

## Solution Layout

```
src/
├── PcIfy.Server.Flutter/    Flutter server (primary)
│   ├── lib/core/             Models, constants, utils
│   ├���─ lib/features/         Screens (main_screen, settings, dialogs)
│   ├── lib/services/         HTTP server, auth, file, thumbnail, log, FFmpeg
│   ├── lib/services/platform/ Tray (desktop), foreground service (Android)
│   ├── lib/providers/        Riverpod providers
│   ├── android/              AndroidManifest, Kotlin MainActivity
│   ├── macos/Runner/         macOS entitlements
│   └── windows/              Inno Setup script
├── PcIfy.Server/            Legacy C# WinForms + Kestrel server
└── PcIfy.Client/            Flutter client
```

## Running the Flutter Server

```bash
cd src/PcIfy.Server.Flutter
flutter pub get
flutter run          # desktop or connected Android device
```

On first run, open Settings → Source Directories and add a folder. Default credentials are `admin`/`admin` — change them in Settings → Users. Settings are stored in the platform application-support directory (e.g. `%APPDATA%\com.pcify.pcify_server\` on Windows, migrated from `%APPDATA%\pcify\` if an existing C# installation is detected).

## Running the Legacy C# Server

```bash
dotnet run --project src/PcIfy.Server
```

Or open `pc-ify.slnx` in Visual Studio. Settings at `%APPDATA%\pcify\settings.json`.

## Running the Client

```bash
cd src/PcIfy.Client
flutter run
```

The `launch.json` at repo root includes a ready-to-use Flutter launch config.

## FFmpeg (Flutter server — video thumbnail generation)

**Windows / macOS:** FFmpeg is auto-downloaded on first video thumbnail request via `FFmpegSetupService`. A progress dialog shows status. Binaries land in `{applicationSupportDir}/ffmpeg/`. To skip, place `ffmpeg.exe` / `ffmpeg` there manually before first run.

**Android:** Uses the `video_thumbnail` plugin (backed by Android's `MediaMetadataRetriever`) — no download needed.

## Architecture Patterns

### Flutter Server: HTTP with `shelf`

The server is built on `shelf` + `shelf_router`. `HttpServerService` creates a `shelf_router.Router`, applies middleware, and calls `shelf_io.serve()`. Middleware stack (innermost to outermost):
1. **Route handlers** — auth, files, thumbnails, system
2. **Connection logging middleware** — records every request after response
3. **CORS middleware** — adds `Access-Control-Allow-*` headers

### JWT Query Parameter for Streaming

Flutter's `media_kit` and `CachedNetworkImage` cannot inject `Authorization` headers. Streaming and thumbnail endpoints therefore also accept the JWT via `?token=<jwt>`. This is implemented in `HttpServerService._extractToken()`. **Do not remove this pattern** — it is required for video and image loading in the client.

The `ApiRoutes.streamingPrefixes` list defines which prefixes accept query-param tokens. All other endpoints require `Authorization: Bearer`.

### PathSanitizer (Security)

Every file request must pass through `PathSanitizer.isPathAllowed()` before any file system access. This prevents path traversal attacks. **Never skip this check** in `FileService` or `ThumbnailService`.

### Flutter Server State Management (Riverpod)

Same pattern as the client. Providers live in `lib/providers/`. `HttpServerService` exposes a `Stream<ServerState>` consumed by `serverStateProvider`. `ConnectionLogService` exposes a `StreamController.broadcast()` consumed by `logEntriesProvider`.

### WinForms + Kestrel Threading (Legacy Server Only)

Kestrel runs on a background thread; WinForms runs on the STA UI thread. Always use `form.Invoke()` when updating controls from Kestrel callbacks. **Not applicable to the Flutter server** — Dart's event loop handles concurrency on a single thread.

### Dark / Light Mode

**Flutter server:** `ThemeNotifier` in `lib/providers/theme_providers.dart` stores `ThemeMode` + accent colour in `SharedPreferences`. The colour mode from `AppSettings.colorMode` (`"Dark"/"Light"/"System"`) is also reflected by applying the corresponding `ThemeMode` via `_applyColorMode` in `SettingsScreen`.

**Legacy C# server:** `Program.ApplyColorMode(string mode)` calls `Application.SetColorMode()`.

**Client:** `ThemeService` in `lib/services/theme_service.dart`.

### Android Foreground Service

On Android, the shelf server runs on the main isolate. `flutter_foreground_task` keeps the process alive in the background by maintaining a foreground `Service` with a persistent notification. `ForegroundServiceImpl` in `lib/services/platform/foreground_service_android.dart` manages start/stop. Started alongside `HttpServerService.start()` and stopped with `HttpServerService.stop()`.

### Desktop Tray (Windows / macOS)

`TrayServiceImpl` in `lib/services/platform/tray_service_desktop.dart` uses `tray_manager` for the tray icon + context menu and `window_manager` for minimize-to-tray. `onWindowClose` in `main.dart` hides the window instead of destroying it (`windowManager.setPreventClose(true)`).

## Adding New API Endpoints (Flutter Server)

1. Add the route constant to `lib/core/constants/api_routes.dart`
2. Add a handler method and register it in `HttpServerService._buildRouter()`
3. Add the corresponding call in the client's `lib/services/api_service.dart`
4. If the endpoint streams a file or serves images, add its prefix to `ApiRoutes.streamingPrefixes`

## Adding New Client Screens

1. Create `lib/features/your_feature/your_screen.dart`
2. Add a route in `lib/router.dart`
3. Add any new services/providers under `lib/services/` and `lib/providers/`

## Adding New API Endpoints (Legacy C# Server)

1. Add the route constant to `PcIfy.Server/Constants/ApiRoutes.cs`
2. Add the controller method in `PcIfy.Server/Api/Controllers/`
3. If the endpoint streams a file, add it to `StreamingPathPrefixes` in `JwtHelper.cs`

## Key Files Quick Reference

### Flutter Server (`PcIfy.Server.Flutter`)

| File | Purpose |
|---|---|
| `lib/core/constants/api_routes.dart` | All API route strings + streaming prefixes |
| `lib/services/http_server_service.dart` | shelf router, middleware, all request handlers |
| `lib/services/auth_service.dart` | JWT generation + BCrypt verification |
| `lib/services/file_service.dart` | File listings, streaming, MIME types |
| `lib/services/thumbnail_service.dart` | Image / video thumbnail generation + cache |
| `lib/services/ffmpeg_setup_service.dart` | FFmpeg binary download (Windows/macOS) |
| `lib/services/settings_service.dart` | Settings load/save, Windows legacy path migration |
| `lib/core/utils/path_sanitizer.dart` | Security — path traversal prevention |
| `lib/services/platform/tray_service_desktop.dart` | Windows/macOS tray icon |
| `lib/services/platform/foreground_service_android.dart` | Android background keep-alive |
| `android/app/src/main/AndroidManifest.xml` | Permissions + foreground service declaration |
| `macos/Runner/Release.entitlements` | macOS sandbox entitlements |
| `windows/installer.iss` | Inno Setup script for Windows installer |

### Legacy C# Server (`PcIfy.Server`)

| File | Purpose |
|---|---|
| `Constants/ApiRoutes.cs` | All API route strings |
| `Program.cs` | Entry point, DI root, colour mode |
| `Services/KestrelHostService.cs` | Embeds Kestrel in WinForms process |
| `Helpers/PathSanitizer.cs` | Security — path traversal prevention |
| `Helpers/JwtHelper.cs` | JWT generation + query-param support |

### Client (`PcIfy.Client`)

| File | Purpose |
|---|---|
| `lib/main.dart` | Flutter entry point |
| `lib/router.dart` | go_router navigation config |
| `lib/services/api_service.dart` | All HTTP calls to server |
| `lib/services/auth_token_service.dart` | JWT storage and retrieval |
| `lib/services/theme_service.dart` | Dark/light + accent colour |
| `lib/providers/` | Riverpod provider definitions |
