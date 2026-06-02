# CLAUDE.md — pc-ify Developer Guide

## Project Overview

**pc-ify** is a local-network home entertainment system:
- **PcIfy.Server.Flutter** — Flutter server app (Windows · Android · macOS) that embeds a `shelf`-based HTTP API to serve files on the local network
- **PcIfy.Client** — Flutter client app (Android · iOS · macOS · Windows) for browsing and streaming those files
- **PcIfy.Server** *(legacy, recommended for Windows)* — .NET 10 WinForms app; the stable Windows option while the Flutter server is in preview

> **Flutter server on Windows — Preview status:** The Flutter server is functional but not yet production-ready on Windows. Known rough edges include slower thumbnail processing compared to the legacy server. For day-to-day Windows use, prefer `PcIfy.Server` (WinForms) until the Flutter version matures.

## Solution Layout

```
src/
├── PcIfy.Server.Flutter/    Flutter server (primary)
│   ├── lib/core/             Models, constants, utils
│   ├── lib/features/         Screens (main_screen, settings, dialogs)
│   ├── lib/services/         HTTP server, auth, file, thumbnail, log, FFmpeg
│   ├── lib/services/platform/ System control, tray (desktop), foreground service (Android)
│   ├── lib/providers/        Riverpod providers
│   ├── android/              AndroidManifest, Kotlin MainActivity, Accessibility service
│   ├── macos/Runner/         AppDelegate.swift (system control), entitlements
│   └── windows/runner/       system_control_channel.cpp/h, Inno Setup script
├── PcIfy.Server/            Legacy C# WinForms + Kestrel server
└── PcIfy.Client/            Flutter client
    ├── lib/core/models/      dashboard_models.dart, control_status.dart, ...
    ├── lib/features/home/    Home screen + customizable dashboard
    ├── lib/features/home/widget_cards/  Battery, CPU, RAM, Volume, ScreenLock cards
    ├── lib/services/         dashboard_layout_service.dart, api_service.dart, ...
    └── lib/providers/        dashboard_providers.dart, services_providers.dart, ...
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
1. **Route handlers** — auth, files, thumbnails, system control
2. **Connection logging middleware** — records every request after response
3. **CORS middleware** — adds `Access-Control-Allow-*` headers

### JWT Query Parameter for Streaming

Flutter's `media_kit` and `CachedNetworkImage` cannot inject `Authorization` headers. Streaming and thumbnail endpoints therefore also accept the JWT via `?token=<jwt>`. This is implemented in `HttpServerService._extractToken()`. **Do not remove this pattern** — it is required for video and image loading in the client.

The `ApiRoutes.streamingPrefixes` list defines which prefixes accept query-param tokens. All other endpoints (including system control) require `Authorization: Bearer`.

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

### System Control Platform Channels

The client polls `/api/system/control/status` every 5 seconds. The server exposes battery, volume, CPU, RAM, and screen-lock state — each field carries `available: bool` so clients degrade gracefully on unsupported platforms.

**Channel name:** `com.pcify.pcify_server/system_control`

| Platform | Implementation | Notes |
|---|---|---|
| Android | `MainActivity.kt` | CPU via `/proc/stat` diff, fallback to `/sys/cpufreq`; screen lock not available (Play Protect flags `BIND_ACCESSIBILITY_SERVICE` + `INTERNET` + `MANAGE_EXTERNAL_STORAGE` as RAT) |
| Windows (Flutter) | `windows/runner/system_control_channel.cpp` | CPU via PDH; volume via `IAudioEndpointVolume` COM; lock via `LockWorkStation()`; wake via `mouse_event()` |
| macOS (Flutter) | `macos/Runner/AppDelegate.swift` | Battery via IOKit; volume via `osascript`; CPU/RAM via `top`/`vm_stat`; lock via `⌃⌘Q` keypress |
| Windows (C#) | `Services/WindowsSystemControlService.cs` | Same capabilities as Flutter Windows channel |

**Android screen lock:** Not supported. Declaring `BIND_ACCESSIBILITY_SERVICE` alongside `INTERNET` + `MANAGE_EXTERNAL_STORAGE` triggers Google Play Protect's RAT heuristic and hard-blocks installation. `screen.available` is always `false` on Android; the client card shows "not available on this platform".

**Android Package ID:** The app is published as `app.pcify.server` (`applicationId` in `build.gradle.kts`). The Kotlin `namespace` remains `com.pcify.pcify_server` so `.ClassName` references in `AndroidManifest.xml` resolve correctly.

### Customizable Dashboard (Client)

The home screen has a fully customizable layout stored in `SharedPreferences` under key `dashboard_layout_v1`.

**Data model** (`lib/core/models/dashboard_models.dart`):
```
DashboardLayout
  └─ List<DashboardSection>
       ├─ id, name, isBookmarks
       └─ List<DashboardItem>
            └─ id, WidgetType, WidgetSize?
```

**Widget types:** `battery`, `volume`, `cpu`, `ram`, `screenLock`

**Widget sizes:** `halfWidth` (two per row) · `fullWidth` (spans row). Battery, CPU, RAM default to half; Volume and ScreenLock default to full. Size can be overridden per item.

**Default layout on first launch:**
1. "Server Overview" → [battery, volume, cpu, ram, screenLock]
2. "My Bookmarks" (`isBookmarks: true`)

**Persistence:** `DashboardLayoutService` saves/loads JSON. On load it silently drops items with unrecognised widget types (forward-compat) and removes sections that become empty after filtering.

**Backup/restore:** `BackupRestoreService.collectBackup()` / `restoreBackup()` accept an `includeDashboardLayout` / `restoreDashboardLayout` flag. The dashboard layout is a separate key, not part of the generic settings keys, so it can be opted in/out independently.

**Edit mode UX:**
- Pencil icon in home screen AppBar toggles `dashboardEditModeProvider`
- Sections reorderable via `ReorderableListView` (drag handle on left)
- Each section: rename (tap name or pencil icon), delete (with Snackbar undo), add/remove/resize/reorder widgets
- Widgets are drag-and-drop across sections (`LongPressDraggable` + `DragTarget`, 400 ms delay). Feedback uses screen-width-based sizing from `MediaQuery`.
- Right-edge resize handle: horizontal drag ≥ 40 px OR ≥ 300 px/s velocity triggers expand/shrink. Handle animates (scale pulse + colour change) during drag.
- `isBookmarks` sections: delete button enabled; item list replaced by static label (items managed in Browse tab)

## System Control API Endpoints

All protected (requires `Authorization: Bearer`):

| Method | Route | Body / Response |
|---|---|---|
| `GET` | `/api/system/control/status` | `ControlStatusDto` — battery, volume, cpu, ram, screen each with `available: bool` |
| `POST` | `/api/system/control/volume` | `{level: 0-100}` |
| `POST` | `/api/system/control/mute` | `{muted: bool}` |
| `POST` | `/api/system/control/lock` | — |
| `POST` | `/api/system/control/wake` | — |

## Adding New API Endpoints (Flutter Server)

1. Add the route constant to `lib/core/constants/api_routes.dart`
2. Add a handler method and register it in `HttpServerService._buildRouter()`
3. Add the corresponding call in the client's `lib/services/api_service.dart`
4. If the endpoint streams a file or serves images, add its prefix to `ApiRoutes.streamingPrefixes`

## Adding a New Dashboard Widget Type

1. Add the value to `WidgetType` enum in `lib/core/models/dashboard_models.dart`
2. Update `_defaultSizeFor()` if it should be half-width by default
3. Create the card widget in `lib/features/home/widget_cards/`
4. Add the case to `_buildCard()` in `dashboard_section_view.dart`
5. Add icon, name, and description to `add_widget_bottom_sheet.dart`
6. Add icon and name to `dashboard_section_editor.dart`

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
| `lib/services/platform/system_control_service.dart` | Abstract `SystemControlService` + DTOs + `SystemControlServiceHelper` singleton |
| `lib/services/platform/system_control_android.dart` | Android MethodChannel implementation |
| `lib/services/platform/system_control_desktop.dart` | Windows/macOS MethodChannel implementation |
| `lib/services/platform/tray_service_desktop.dart` | Windows/macOS tray icon |
| `lib/services/platform/foreground_service_android.dart` | Android background keep-alive |
| `android/app/src/main/AndroidManifest.xml` | Permissions + service declarations |
| `android/app/src/main/kotlin/.../MainActivity.kt` | MethodChannel handlers for permissions + system control |
| `android/app/src/main/kotlin/.../PcIfyAccessibilityService.kt` | Remote screen lock via Accessibility API |
| `android/app/src/main/res/xml/accessibility_service_config.xml` | Accessibility service configuration |
| `macos/Runner/AppDelegate.swift` | macOS system control MethodChannel |
| `windows/runner/system_control_channel.cpp` | Windows system control MethodChannel (PDH, COM audio, P/Invoke) |
| `macos/Runner/Release.entitlements` | macOS sandbox entitlements |
| `windows/installer.iss` | Inno Setup script for Windows installer |

### Legacy C# Server (`PcIfy.Server`)

| File | Purpose |
|---|---|
| `Constants/ApiRoutes.cs` | All API route strings |
| `Program.cs` | Entry point, DI root, colour mode |
| `Services/KestrelHostService.cs` | Embeds Kestrel in WinForms process |
| `Services/WindowsSystemControlService.cs` | Battery/CPU/RAM/Volume/Lock via Win32 APIs |
| `Services/Interfaces/ISystemControlService.cs` | System control interface |
| `DTOs/System/ControlStatusDto.cs` | Status response DTOs |
| `Api/Controllers/SystemControlController.cs` | System control HTTP endpoints |
| `Helpers/PathSanitizer.cs` | Security — path traversal prevention |
| `Helpers/JwtHelper.cs` | JWT generation + query-param support |

### Client (`PcIfy.Client`)

| File | Purpose |
|---|---|
| `lib/main.dart` | Flutter entry point |
| `lib/router.dart` | go_router navigation config |
| `lib/core/models/dashboard_models.dart` | `DashboardLayout`, `DashboardSection`, `DashboardItem`, `WidgetType`, `WidgetSize` |
| `lib/core/models/control_status.dart` | `ControlStatus`, `BatteryStatus`, `VolumeStatus`, `CpuStatus`, `RamStatus`, `ScreenStatus` DTOs |
| `lib/features/home/home_screen.dart` | Home screen — background image/video logic, AppBar with edit toggle |
| `lib/features/home/dashboard_body.dart` | Switches between view and edit mode |
| `lib/features/home/dashboard_section_view.dart` | Section renderer — widget grid, drag-and-drop, resize handle |
| `lib/features/home/dashboard_edit_view.dart` | Edit mode — section reorder, add/delete/rename sections |
| `lib/features/home/dashboard_section_editor.dart` | Per-section widget list with resize/remove/reorder |
| `lib/features/home/add_widget_bottom_sheet.dart` | Widget type picker bottom sheet |
| `lib/features/home/add_section_dialog.dart` | New section dialog (custom name or My Bookmarks) |
| `lib/features/home/widget_cards/battery_card.dart` | Battery level + charging state |
| `lib/features/home/widget_cards/cpu_card.dart` | CPU usage percentage bar |
| `lib/features/home/widget_cards/ram_card.dart` | RAM used/total bar |
| `lib/features/home/widget_cards/volume_card.dart` | Volume slider + mute toggle |
| `lib/features/home/widget_cards/screen_lock_card.dart` | Lock / Wake buttons |
| `lib/features/home/widget_cards/bookmark_section_body.dart` | Bookmarked folders grid (extracted from home_screen) |
| `lib/services/api_service.dart` | All HTTP calls to server |
| `lib/services/dashboard_layout_service.dart` | Dashboard layout persistence (`dashboard_layout_v1`) |
| `lib/services/backup_restore_service.dart` | Backup/restore including dashboard layout |
| `lib/services/auth_token_service.dart` | JWT storage and retrieval |
| `lib/services/theme_service.dart` | Dark/light + accent colour |
| `lib/providers/dashboard_providers.dart` | `dashboardLayoutProvider`, `controlStatusProvider` (5s poll), `dashboardEditModeProvider` |
| `lib/providers/services_providers.dart` | All service providers including `dashboardLayoutServiceProvider` |
