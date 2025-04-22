#!/usr/bin/env bash
# test_foot.sh – Run foot terminal if Weston is running

set -euo pipefail

echo "[foot-test] 🔧 Starting test_foot.sh"

# Set up socket search path
SOCKET_DIR="/run/user/$(id -u)"
echo "[foot-test] 🔍 Looking for Wayland socket in: $SOCKET_DIR"

# Find Wayland socket (wayland-0, wayland-1, etc.)
WAYLAND_SOCKET=$(find "$SOCKET_DIR" -maxdepth 1 -type s -name 'wayland-*' 2>/dev/null | head -n1)

if [[ -z "$WAYLAND_SOCKET" ]]; then
  echo "[foot-test] ❌ No Wayland socket found. Weston is likely not running."
  exit 1
fi

echo "[foot-test] ✅ Found Wayland socket: $WAYLAND_SOCKET"

# Export environment variables needed by Wayland clients
export XDG_RUNTIME_DIR="$SOCKET_DIR"
export WAYLAND_DISPLAY="$(basename "$WAYLAND_SOCKET")"

echo "[foot-test] 🚀 Attempting to launch foot using display: $WAYLAND_DISPLAY"
foot || echo "[foot-test] ❌ Foot failed to launch!"
