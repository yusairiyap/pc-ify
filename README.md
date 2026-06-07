# pc-ify

A local-network home entertainment app. Run the server on Windows, Android, or macOS and browse, stream, and download your files from any device on the same Wi-Fi network — no internet required.

## Features

### Server (Windows · Android · macOS)

> **Preview notice (Windows):** The Flutter server on Windows is still in preview — some features (e.g. thumbnail processing speed) are not yet on par with the legacy server. For best stability on Windows, use the legacy WinForms server (`PcIfy.Server`) until the Flutter version matures.

- Embedded HTTP API built with Dart `shelf` — no external dependencies
- JWT-authenticated API (username + password, configurable)
- Per-user directory ACL — restrict each account to specific source folders
- Configurable port number and server name
- Auto-start server on launch (optional)
- One-click copy of the server IP address
- **Windows / macOS:** Minimize to system tray with running/stopped indicator
- **Android:** Persistent foreground notification keeps the server running while the app is in the background
- Full connection log: client IP, username, timestamp, action
- Dark / Light / System colour mode
- Video thumbnail generation via `video_thumbnail` (Android) or FFmpeg download (Windows/macOS)
- Image thumbnail generation
- **System telemetry:** Exposes live battery (with temperature), CPU, RAM, volume, screen-lock state, clipboard content, and app-launcher status to the client over the local network
- Settings import / export

> **Legacy server (recommended for Windows):** The original `PcIfy.Server` WinForms project (C# / .NET 10) is the stable option for Windows users while the Flutter server is in preview. It can be built and run independently from `src/PcIfy.Server`.

### Client (Android · iOS · macOS · Windows)
- Clean file/folder browser with thumbnail grid
- Resizable grid density (Compact / Normal / Large)
- **Customizable home dashboard** — add, remove, rename, and reorder sections; drag widgets between sections; resize cards between half-width and full-width with an animated edge handle
- **System widget cards:** Battery level + temperature, CPU usage, RAM usage, Volume slider + mute toggle, Screen Lock / Wake, **Clipboard** (live PC clipboard with one-tap copy to phone), **App Launcher** (grid of configured PC apps with running-process indicators)
- Per-folder background image or video with crop/zoom customisation
- In-app video streaming (seek/fast-forward without full download)
- Split-pane video player with pinch zoom/pan and mute
- Open video in external player (VLC, MX Player, etc.)
- Image gallery with smooth swipe paging
- File download
- Backup and restore: bookmarks, folder preferences, and dashboard layout
- App lock (PIN / biometrics)
- Dark / Light / System theme + customisable accent colour
- **First-run wizard** — guides through accent colour, theme, and grid density; launches before the server connection screen on fresh installs
- **About page** in Settings (developer + GitHub link)

## Requirements

| Component | Requirement |
|---|---|
| Server (Windows) | Windows 10/11 64-bit |
| Server (Android) | API 26+ (Android 8.0+), `Allow access to all files` permission |
| Server (macOS) | macOS 10.14+ |
| Client (Android) | API 21+ (Android 5.0+) |
| Client (iOS) | iOS 12+ |
| Network | Both devices on the same Wi-Fi / LAN |

## Setup

### Flutter Server (Windows / Android / macOS)

1. Build and run `PcIfy.Server.Flutter` (see Build section below)
2. Tap **Settings** → **Source Directories** → add the folders you want to share
3. (Optional) Change the default `admin`/`admin` credentials in **Settings → Users**
4. (Optional) Set a custom server name and port in **Settings → General**
5. Tap **Start Server** — the status card shows the IP and port; tap the copy icon to copy the IP address

> **Android:** Grant **Allow access to all files** (Settings → Special app access) so the server can read arbitrary directories you configure.
>
> **Windows / macOS video thumbnails:** FFmpeg is downloaded automatically on first use (~30 MB). You will be prompted once — tap **Download** to enable video thumbnail support.

### Legacy Windows Server (C# / WinForms)

1. Build `src/PcIfy.Server` with `dotnet build` or Visual Studio
2. Click **Settings → Directories** → add source folders
3. Change default `admin`/`admin` credentials in **Settings → Users**
4. Click **Start Server**

### Client

1. Install the app on your device
2. On first launch a short wizard lets you choose accent colour, theme, and grid density
3. Enter the server's local IP and port (shown in the server app — tap the copy icon)
4. Log in with your configured credentials
5. Browse, stream, and download your files

### Customising the Home Dashboard

The home screen starts with a "Server Overview" section (battery, volume, CPU, RAM, screen lock) and a "My Bookmarks" section. Additional widgets — Clipboard, App Launcher, Disk Space, and Server Info — can be added from the widget picker.

- Tap the **pencil icon** in the top bar to enter edit mode
- **Reorder sections** by dragging the handle on the left
- **Add a section** with the "Add section" button at the bottom (custom name, or re-add "My Bookmarks")
- **Rename** a section by tapping the name or the pencil icon
- **Add / remove widgets** within a section
- **Resize a card** using the dot handle on the right edge — swipe right to expand to full width, swipe left to shrink to half width
- **Drag a widget** (long-press 400 ms) to reorder within a section or move it to another section
- Tap the pencil icon again (or the checkmark) to save and exit edit mode

## Build

```bash
# Flutter server (run from src/PcIfy.Server.Flutter)
flutter pub get
flutter run                           # desktop / connected device
flutter build apk --release           # Android APK
flutter build windows --release       # Windows exe + DLLs
flutter build macos --release         # macOS .app

# Flutter client (run from src/PcIfy.Client)
flutter pub get
flutter run
flutter build apk --release
flutter build ios --release           # requires macOS + Xcode
flutter build windows --release
flutter build macos --release

# Legacy C# server
dotnet build src/PcIfy.Server
```

## CI / Artifacts

| Workflow | Trigger | Artifacts |
|---|---|---|
| **Build Android APKs** | Push to `src/PcIfy.Client/**` or `src/PcIfy.Server.Flutter/**` | Client APK + Server APK (arm64 + universal) |
| **Build Windows Executables** | Push to either Flutter source path | Client ZIP + Server ZIP; **on `main` only:** client + server Inno Setup installers |

Manual dispatch supports a `build_target` choice to build only the client or only the server.

## Architecture

```
src/
├── PcIfy.Server.Flutter/    Flutter server (Windows · Android · macOS)
│   ├── lib/core/             Models, constants, utils
│   ├── lib/features/         Screens (main, settings, dialogs)
│   ├── lib/services/         HTTP server, auth, file, thumbnail, log, FFmpeg
│   ├── lib/services/platform/ System control (Android/desktop), tray, foreground service
│   └── lib/providers/        Riverpod providers
├── PcIfy.Server/            Legacy WinForms server (C# / .NET 10) — kept for reference
└── PcIfy.Client/            Flutter client (Android · iOS · macOS · Windows)
    ├── lib/core/models/      dashboard_models.dart, control_status.dart, ...
    ├── lib/features/home/    Customizable dashboard + widget cards
    ├── lib/services/         api_service.dart, dashboard_layout_service.dart, ...
    └── lib/providers/        dashboard_providers.dart, ...
```

### System Control API

The client polls the server every 5 seconds for live device status. All endpoints require `Authorization: Bearer`.

| Method | Route | Description |
|---|---|---|
| `GET` | `/api/system/control/status` | Battery (+ temperature), CPU, RAM, volume, screen — each with `available: bool` |
| `POST` | `/api/system/control/volume` | `{level: 0-100}` |
| `POST` | `/api/system/control/mute` | `{muted: bool}` |
| `POST` | `/api/system/control/lock` | Lock screen |
| `POST` | `/api/system/control/wake` | Wake screen |
| `GET` | `/api/system/control/clipboard` | PC clipboard text with format hint (`text`/`url`/`code`) |
| `GET` | `/api/system/apps` | List of configured launcher apps with running-process state |
| `POST` | `/api/system/apps/launch` | `{id}` — launch app by id |
| `POST` | `/api/system/apps/add` | `{name, executablePath, processName?, iconKey?}` — add app to launcher |
| `DELETE` | `/api/system/apps/{id}` | Remove app from launcher |

Platform coverage:

| Capability | Android | Windows | macOS |
|---|---|---|---|
| Battery | ✓ | ✓ (desktop = no battery) | ✓ |
| Battery temperature | ✓ (`BatteryManager`) | ✓ (WMI `Win32_Battery`) | ✓ (IOKit) |
| Volume / Mute | ✓ | ✓ | ✓ |
| CPU usage | ✓ | ✓ | ✓ |
| RAM usage | ✓ | ✓ | ✓ |
| Screen lock | — | ✓ | ✓ |
| Screen wake | ✓ | ✓ | ✓ |
| Clipboard read | ✓ | ✓ | ✓ |
| App launcher | — | ✓ | ✓ |

See [CLAUDE.md](CLAUDE.md) for detailed developer documentation.
