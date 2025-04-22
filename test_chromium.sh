#!/usr/bin/env bash
# test_chromium.sh
# -----------------------------------------------------------------------------
# Launches Flatpak Chromium in Wayland mode bypassing the document portal,
# which causes permission errors in minimal kiosk environments.
# -----------------------------------------------------------------------------

set -euo pipefail

echo "[chromium-test] 🧪 Starting Chromium Wayland test..."

# Identify Wayland socket from /run/user/<UID>
USER_ID=$(id -u gui)
SOCKET_DIR="/run/user/$USER_ID"
SOCKET=$(find "$SOCKET_DIR" -maxdepth 1 -type s -name 'wayland-*' | head -n1)

if [ -z "$SOCKET" ]; then
  echo "[chromium-test] ❌ No Wayland socket found at $SOCKET_DIR"
  exit 1
fi

WAYLAND_DISPLAY=$(basename "$SOCKET")

# Export required environment variables
export XDG_RUNTIME_DIR="$SOCKET_DIR"
export WAYLAND_DISPLAY="$WAYLAND_DISPLAY"

echo "[chromium-test] ✅ Wayland socket found: $WAYLAND_DISPLAY"
echo "[chromium-test] 🚀 Launching Chromium (Wayland mode)..."

# Run Chromium in Flatpak with sandbox bypass for kiosk
sudo -u gui \
  XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
  WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  dbus-run-session -- \
  flatpak run \
    --filesystem=home \
    --talk-name=org.freedesktop.portal.Fallback \
    --env=GDK_BACKEND=wayland \
    org.chromium.Chromium \
    --ozone-platform=wayland \
    --disable-features=UseOzonePlatformForVideo
