# pc-ify

A local-network home entertainment app. Run the server on your Windows PC and browse, stream, and download your files from your Android or iOS device — no internet required.

## Features

### Server (Windows)
- Embedded HTTP API hosted in a WinForms app — one `.exe`, no setup wizard
- JWT-authenticated API (username + password, configurable)
- Configurable port number
- Minimize to system tray with running/stopped indicator
- Full connection log: client IP, username, timestamp, action
- Dark / Light / System color mode toggle
- Video thumbnail generation via FFmpeg
- Image thumbnail generation

### Client (Android / iOS)
- Clean file/folder browser with thumbnail grid
- Resizable grid density (Compact / Normal / Large)
- Homepage with bookmarked folders
- Per-folder background image with crop/zoom customization
- In-app video streaming (seek/fast-forward without full download)
- Open video in external player (VLC, MX Player, etc.)
- Image gallery with smooth swipe paging
- File download
- Dark / Light / System theme + customizable accent color
- Animated page transitions
- Tablet-optimized layout (two-pane mode)

## Requirements

| Component | Requirement |
|---|---|
| Server OS | Windows 10/11 |
| Server Runtime | .NET 10 |
| Android | API 21+ (Android 5.0+) |
| iOS | iOS 15+ |
| Network | Both devices on the same Wi-Fi network |

## Setup

### Server

1. Build and run `PcIfy.Server`
2. Click **Settings** → **Directories** → add the folders you want to share
3. (Optional) Change the default `admin`/`admin` credentials in **Settings → Users**
4. Click **Start Server** — the status bar shows the IP and port

> **Video thumbnails:** FFmpeg is downloaded automatically on first launch (~30 MB from GitHub). You will be prompted once — click Yes to enable video thumbnail support.

### Client

1. Install the app on your Android or iOS device
2. Enter the server's local IP address and port (shown in the server window)
3. Log in with your configured credentials
4. Browse, stream, and download your files

## Build

```bash
# Server
dotnet build src/PcIfy.Server

# Client (Android)
dotnet build src/PcIfy.Client -f net10.0-android

# Client (iOS — requires macOS + Xcode)
dotnet build src/PcIfy.Client -f net10.0-ios
```

## Architecture

```
src/
├── PcIfy.Shared/    DTOs, API route constants, MIME helpers
├── PcIfy.Server/    WinForms + embedded Kestrel API
│   ├── Api/         Controllers, middleware
│   ├── Forms/       WinForms UI (MainForm, SettingsForm, tray)
│   ├── Services/    Business logic (file, auth, thumbnail, log)
│   ├── Helpers/     JWT, path security, range requests
│   └── Models/      AppSettings, log entries
└── PcIfy.Client/    .NET MAUI (Android + iOS)
    ├── Views/        XAML pages + code-behind
    ├── ViewModels/   MVVM logic (CommunityToolkit.Mvvm)
    ├── Services/     HTTP client, auth token, theme, bookmarks
    ├── Helpers/      Grid density, image crop, file size
    └── Converters/   XAML value converters
```

See [CLAUDE.md](CLAUDE.md) for detailed developer documentation.
