#!/usr/bin/env bash
# test_wayland_app.sh — verify a Wayland client can talk to Weston

set -euo pipefail

GUI_USER=gui
GUI_UID=$(id -u $GUI_USER)
RUNTIME_DIR="/run/user/$GUI_UID"

echo "[test] runtime dir = $RUNTIME_DIR"

# 1) find the live Wayland socket
SOCKET=$(find "$RUNTIME_DIR" -maxdepth 1 -type s -name 'wayland-*' 2>/dev/null | head -n1)
if [ -z "$SOCKET" ]; then
  echo "[test] ❌ no wayland socket in $RUNTIME_DIR" >&2
  exit 1
fi

WAYLAND_DISPLAY=$(basename "$SOCKET")
echo "[test] using WAYLAND_DISPLAY=$WAYLAND_DISPLAY"

# 2) now launch Foot with the right env, as the gui user
sudo -u $GUI_USER env \
  XDG_RUNTIME_DIR="$RUNTIME_DIR" \
  WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  foot
