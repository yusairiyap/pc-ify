# pc-ify

A local-network home entertainment app. Run the server on your Windows PC and browse, stream, and download your files from your Android or iOS device — no internet required.

## Features

### Server (Windows)
- Embedded HTTP API hosted in a WinForms app — one `.exe`, no setup wizard
- JWT-authenticated API (username + password, configurable)
- Configurable port number and server name
- Auto-start server on launch (optional)
- One-click copy of the connection address
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

## Requirements

| Component | Requirement |
|---|---|
| Server OS | Windows 10/11 |
| Server Runtime | .NET 10 |
| Android | API 21+ (Android 5.0+) |
| iOS | iOS 12+ |
| Network | Both devices on the same Wi-Fi network |

## Setup

### Server

1. Build and run `PcIfy.Server`
2. Click **Settings** → **Directories** → add the folders you want to share
3. (Optional) Change the default `admin`/`admin` credentials in **Settings → Users**
4. (Optional) Set a custom server name and port in **Settings → General**
5. Click **Start Server** — the status bar shows the IP and port; use **Copy** to copy the address

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
cd src/PcIfy.Client
flutter build apk

# Client (iOS — requires macOS + Xcode)
flutter build ios
```

## Architecture

```
src/
├── PcIfy.Server/          WinForms + embedded Kestrel API
│   ├── Api/               Controllers, middleware
│   ├── Constants/         API route strings, MIME type helpers
│   ├── DTOs/              Request/response data objects
│   ├── Forms/             WinForms UI (MainForm, SettingsForm, tray)
│   ├── Helpers/           JWT, path security, range requests
│   ├── Models/            AppSettings, log entries
│   └── Services/          Business logic (file, auth, thumbnail, log)
└── PcIfy.Client/          Flutter client (Android + iOS)
    ├── lib/core/           Models, constants, utils
    ├── lib/features/       Screen widgets (browser, home, video, gallery…)
    ├── lib/services/       HTTP, auth token, bookmarks, theme, download
    ├── lib/providers/      Riverpod providers
    └── lib/widgets/        Shared shell widget
```

See [CLAUDE.md](CLAUDE.md) for detailed developer documentation.
