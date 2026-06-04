#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Run in background — session starts immediately while Flutter installs
echo '{"async": true, "asyncTimeout": 300000}'

FLUTTER_DIR="/opt/flutter"
FLUTTER_BIN="$FLUTTER_DIR/bin/flutter"

# ── Install Flutter SDK if not present ────────────────────────────────────────
if [ ! -f "$FLUTTER_BIN" ]; then
  echo "Flutter not found — installing Flutter stable to $FLUTTER_DIR ..."
  git clone --depth 1 --branch stable \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  echo "Flutter cloned."
else
  echo "Flutter already installed at $FLUTTER_DIR"
fi

# ── Make flutter available for the rest of this session ───────────────────────
export PATH="$FLUTTER_DIR/bin:$PATH"
echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"

# ── First-run bootstrap (downloads Dart SDK, sets up tool cache) ──────────────
# Suppress interactive prompts and analytics
"$FLUTTER_BIN" config --no-analytics --no-cli-animations 2>/dev/null || true
"$FLUTTER_BIN" --version

# ── Install client dependencies ────────────────────────────────────────────────
CLIENT_DIR="$CLAUDE_PROJECT_DIR/src/PcIfy.Client"
if [ -f "$CLIENT_DIR/pubspec.yaml" ]; then
  echo "Running flutter pub get for PcIfy.Client ..."
  (cd "$CLIENT_DIR" && "$FLUTTER_BIN" pub get)
  echo "Client dependencies installed."
fi

# ── Install server dependencies ────────────────────────────────────────────────
SERVER_DIR="$CLAUDE_PROJECT_DIR/src/PcIfy.Server.Flutter"
if [ -f "$SERVER_DIR/pubspec.yaml" ]; then
  echo "Running flutter pub get for PcIfy.Server.Flutter ..."
  (cd "$SERVER_DIR" && "$FLUTTER_BIN" pub get)
  echo "Server dependencies installed."
fi

# ── Java 17 (required for local APK builds via /build-apk) ────────────────────
if ! java -version 2>&1 | grep -q 'version "17'; then
  echo "Installing OpenJDK 17 ..."
  apt-get update -qq && apt-get install -y --no-install-recommends openjdk-17-jdk-headless 2>/dev/null || true
fi
JAVA_HOME_PATH="/usr/lib/jvm/java-17-openjdk-amd64"
if [ -d "$JAVA_HOME_PATH" ]; then
  export JAVA_HOME="$JAVA_HOME_PATH"
  echo "export JAVA_HOME=\"$JAVA_HOME_PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# ── Android SDK (required for local APK builds via /build-apk) ────────────────
ANDROID_SDK_DIR="/opt/android-sdk"
SDKMANAGER="$ANDROID_SDK_DIR/cmdline-tools/latest/bin/sdkmanager"
if [ ! -f "$SDKMANAGER" ]; then
  echo "Installing Android SDK cmdline-tools ..."
  CMDTOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  wget -q "$CMDTOOLS_URL" -O /tmp/cmdline-tools.zip
  mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"
  unzip -q /tmp/cmdline-tools.zip -d "$ANDROID_SDK_DIR/cmdline-tools"
  mv "$ANDROID_SDK_DIR/cmdline-tools/cmdline-tools" "$ANDROID_SDK_DIR/cmdline-tools/latest"
  rm -f /tmp/cmdline-tools.zip
  echo "Accepting Android SDK licenses ..."
  yes | "$SDKMANAGER" --sdk_root="$ANDROID_SDK_DIR" --licenses > /dev/null 2>&1 || true
  echo "Installing Android SDK components ..."
  "$SDKMANAGER" --sdk_root="$ANDROID_SDK_DIR" \
    "platform-tools" "platforms;android-36" "build-tools;36.0.0"
  echo "Android SDK installed."
else
  echo "Android SDK already present at $ANDROID_SDK_DIR"
fi
export ANDROID_HOME="$ANDROID_SDK_DIR"
export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
echo "export ANDROID_HOME=\"$ANDROID_SDK_DIR\"" >> "$CLAUDE_ENV_FILE"
echo "export ANDROID_SDK_ROOT=\"$ANDROID_SDK_DIR\"" >> "$CLAUDE_ENV_FILE"

echo "Session start hook complete. 'flutter analyze' and '/build-apk' are ready."
