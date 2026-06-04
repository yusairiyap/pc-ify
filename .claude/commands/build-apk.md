Build Flutter APK(s) for pc-ify and send them to the user as downloadable files.

**Usage:** `/build-apk [client|server|both]`

Defaults to `both` if no argument is given.

---

## Instructions

### Step 1 — Parse the target

Read `$ARGUMENTS`, trim whitespace, lowercase it.
- Empty or `"both"` → build both apps
- `"client"` → build PcIfy.Client only
- `"server"` → build PcIfy.Server.Flutter only
- Anything else → tell the user the valid options and stop

Tell the user which app(s) will be built before doing anything else.

---

### Step 2 — Choose build path

Check whether `$GITHUB_TOKEN` is set (non-empty).

- **If set** → use **Path A: GitHub Actions** (release-signed, free compute)
- **If not set** → use **Path B: Local build** (debug-signed, uses this container)

---

## Path A — GitHub Actions (primary)

This path triggers the existing `build-apk.yml` workflow on GitHub, waits for
it to finish, downloads the artifact ZIP, extracts the APK, and sends it.

### A1 — Map the target to workflow input

| Skill arg | Workflow `build_target` input |
|---|---|
| `both` | `both` |
| `client` | `client only` |
| `server` | `server only` |

### A2 — Trigger the workflow

Use the `mcp__github__actions_run_trigger` tool:
- repo: `yusairiyap/pc-ify`
- workflow: `build-apk.yml`
- ref: `main`
- inputs: `{ "build_target": "<mapped value above>" }`

Note the current UTC time so you can identify the new run.

### A3 — Wait for the run to start, then poll for completion

Wait 15 seconds for the run to register, then use `mcp__github__actions_list`
(repo: `yusairiyap/pc-ify`, workflow: `build-apk.yml`) to find the run that
started at or after the time you noted. Check its `status` field.

Poll every 30 seconds. After each check, tell the user the elapsed time and
current status (e.g. "Build running — 2 min elapsed...").

Time out after 25 minutes and tell the user to check the Actions tab manually.

### A4 — Verify success

When `status` is `completed`:
- If `conclusion` is `success` → continue
- Otherwise → tell the user the build failed, show the run URL
  (`https://github.com/yusairiyap/pc-ify/actions`), and stop

### A5 — List artifacts

Use curl to list artifacts for the completed run:

```bash
RUN_ID="<the run id>"
curl -s \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/yusairiyap/pc-ify/actions/runs/$RUN_ID/artifacts"
```

From the JSON response, find artifacts whose name matches:
- `pcify-client-arm64-*` — for the client APK
- `pcify-server-arm64-*` — for the server APK

Only collect artifacts for apps that were requested.

### A6 — Download and extract each APK

For each artifact:

```bash
ARTIFACT_ID="<id>"
APP="client"   # or "server"

curl -L \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/yusairiyap/pc-ify/actions/artifacts/$ARTIFACT_ID/zip" \
  -o "/tmp/pcify-${APP}-artifact.zip"

mkdir -p "/tmp/pcify-${APP}-apk"
unzip -o "/tmp/pcify-${APP}-artifact.zip" -d "/tmp/pcify-${APP}-apk/"
```

The APK file will be at `/tmp/pcify-${APP}-apk/app-arm64-v8a-release.apk`.

### A7 — Deliver the APK(s)

For each extracted APK, use the `SendUserFile` tool:
- path: `/tmp/pcify-${APP}-apk/app-arm64-v8a-release.apk`
- caption: `pcify-client-arm64-release-signed.apk` or `pcify-server-arm64-release-signed.apk`

Then tell the user:
- The APK is **release-signed** and can be installed directly on Android devices
- To enable sideloading: Settings → Security → "Install from unknown sources"
- For a link to the Actions run where it came from

---

## Path B — Local build fallback

Used when `$GITHUB_TOKEN` is not set. Tell the user:

> No GITHUB_TOKEN found — building locally inside this container.
> The APK will be **debug-signed** (installable via sideload, not publishable to Play Store).
> Set GITHUB_TOKEN in your environment config for release-signed builds.

### B1 — Environment setup (run once)

```bash
export PATH="/opt/flutter/bin:$PATH"
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
export ANDROID_HOME="/opt/android-sdk"
export ANDROID_SDK_ROOT="/opt/android-sdk"
```

**Check Flutter:**
```bash
flutter --version
```
If this fails, tell the user the session-start hook may still be running
(it installs Flutter in the background) and ask them to retry in a minute.

**Check Java 17:**
```bash
java -version 2>&1 | head -1
```
If Java 17 is not present, install it:
```bash
apt-get update -qq && apt-get install -y --no-install-recommends openjdk-17-jdk-headless
```

**Check Android SDK:**
```bash
ls /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager 2>/dev/null
```
If missing, install it (this takes ~3–5 minutes — tell the user):
```bash
CMDTOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
wget -q "$CMDTOOLS_URL" -O /tmp/cmdline-tools.zip
mkdir -p /opt/android-sdk/cmdline-tools
unzip -q /tmp/cmdline-tools.zip -d /opt/android-sdk/cmdline-tools
mv /opt/android-sdk/cmdline-tools/cmdline-tools /opt/android-sdk/cmdline-tools/latest
rm /tmp/cmdline-tools.zip
SDKMANAGER=/opt/android-sdk/cmdline-tools/latest/bin/sdkmanager
yes | "$SDKMANAGER" --sdk_root=/opt/android-sdk --licenses > /dev/null 2>&1 || true
"$SDKMANAGER" --sdk_root=/opt/android-sdk \
  "platform-tools" "platforms;android-36" "build-tools;36.0.0"
```

### B2 — Build each app

Repeat for each requested app. Paths and names:

| App | Directory | `--org` | `--project-name` |
|---|---|---|---|
| client | `src/PcIfy.Client` | `com.pcify` | `pcify_client` |
| server | `src/PcIfy.Server.Flutter` | `com.pcify` | `pcify_server` |

```bash
cd /home/user/pc-ify/src/PcIfy.Client   # adjust for server

flutter pub get

flutter create \
  --org com.pcify \
  --project-name pcify_client \
  --platforms=android .

flutter analyze --no-fatal-infos
# If analyze exits non-zero, report the errors but continue to build.
# Fatal analysis failures will be caught by the build step instead.

flutter build apk --release --split-per-abi
```

### B3 — Deliver the APK(s)

APK output path (same for both apps):
```
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Use `SendUserFile` for each:
- caption: `pcify-client-arm64-debug-signed.apk` or `pcify-server-arm64-debug-signed.apk`

Then tell the user:
- The APK is **debug-signed** — suitable for sideloading/testing
- For a release-signed build, set `GITHUB_TOKEN` in your Claude Code environment config and re-run `/build-apk`
