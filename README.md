# pc-ify

A local-network home entertainment app. Run the server on Windows, Android, or macOS and browse, stream, and download your files from any device on the same Wi-Fi network — no internet required.

## Features

### Server (Windows · Android · macOS)

> **Preview notice (Windows):** The Flutter server on Windows is still in preview — some features (e.g. thumbnail processing speed) are not yet on par with the legacy server. For best stability on Windows, use the legacy WinForms server (`PcIfy.Server`) until the Flutter version matures.

- Embedded HTTP API built with Dart `shelf` — no external dependencies
- JWT-authenticated API (username + password, configurable)
- Configurable port number and server name
- Auto-start server on launch (optional)
- One-click copy of the connection address
- **Windows / macOS:** Minimize to system tray with running/stopped indicator
- **Android:** Persistent foreground notification keeps the server running while the app is in the background
- Full connection log: client IP, username, timestamp, action
- Dark / Light / System colour mode
- Video thumbnail generation via `video_thumbnail` (Android) or FFmpeg download (Windows/macOS)
- Image thumbnail generation

> **Legacy server (recommended for Windows):** The original `PcIfy.Server` WinForms project (C# / .NET 10) is the stable option for Windows users while the Flutter server is in preview. It can be built and run independently from `src/PcIfy.Server`.

### Client (Android · iOS · macOS · Windows)
- Clean file/folder browser with thumbnail grid
- Resizable grid density (Compact / Normal / Large)
- Homepage with bookmarked folders
- Per-folder background image with crop/zoom customisation
- In-app video streaming (seek/fast-forward without full download)
- Open video in external player (VLC, MX Player, etc.)
- Image gallery with smooth swipe paging
- File download
- Dark / Light / System theme + customisable accent colour

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
5. Tap **Start Server** — the status card shows the IP and port; tap the copy icon to copy the address

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
2. Enter the server's local IP and port (shown in the server app)
3. Log in with your configured credentials
4. Browse, stream, and download your files

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

## Architecture

```
src/
├── PcIfy.Server.Flutter/    Flutter server (Windows · Android · macOS)
│   ├── lib/core/             Models, constants, utils
│   ├── lib/features/         Screens (main, settings, dialogs)
│   ├── lib/services/         HTTP server, auth, file, thumbnail, log, FFmpeg
│   ├── lib/services/platform/ Tray (desktop), foreground service (Android)
│   └── lib/providers/        Riverpod providers
├── PcIfy.Server/            Legacy WinForms server (C# / .NET 10) — kept for reference
└── PcIfy.Client/            Flutter client (Android · iOS · macOS · Windows)
    ├── lib/core/
    ├── lib/features/
    ├── lib/services/
    ├── lib/providers/
    └── lib/widgets/
```

See [CLAUDE.md](CLAUDE.md) for detailed developer documentation.
