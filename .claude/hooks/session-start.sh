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
  echo "Dependencies installed."
fi

echo "Session start hook complete. 'flutter analyze' is ready."
