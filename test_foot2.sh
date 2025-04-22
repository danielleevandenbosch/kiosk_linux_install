#!/usr/bin/env bash
# test_foot.sh - Run foot terminal inside a Weston session

echo "[foot-test] 🟡 Starting test_foot.sh"

SOCKET_DIR="/run/user/$(id -u)"
echo "[foot-test] 🔍 Checking for Weston sockets under $SOCKET_DIR..."
find "$SOCKET_DIR" -type s -name 'wayland-*'

WAYLAND_SOCKET=$(find "$SOCKET_DIR" -type s -name 'wayland-*' | head -n1)
if [ -z "$WAYLAND_SOCKET" ]; then
  echo "[foot-test] ❌ No Wayland socket found. Weston might not be running."
  exit 1
fi

export XDG_RUNTIME_DIR="$SOCKET_DIR"
export WAYLAND_DISPLAY="$(basename "$WAYLAND_SOCKET")"

echo "[foot-test] 🧪 Trying to launch foot on $WAYLAND_DISPLAY"
foot
