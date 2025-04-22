#!/usr/bin/env bash
# test_foot2.sh
# ─────────────────────────────────────────────────────────────────────────────
# Test launching a Wayland-native app (foot) under a running Weston session.
#
# Usage:  sudo bash test_wayland_app.sh
# You should see a Foot terminal appear in the Weston window.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# 1) Find the GUI user's UID and runtime directory
GUI_UID=$(id -u gui)
RUNTIME_DIR="/run/user/$GUI_UID"

echo "[test] Using runtime dir: $RUNTIME_DIR"

# 2) Locate the first wayland socket (e.g. wayland-0, wayland-1, etc.)
SOCKET_PATH=$(find "$RUNTIME_DIR" -maxdepth 1 -type s -name 'wayland-*' | head -n1)
if [ -z "$SOCKET_PATH" ]; then
  echo "[test] ❌ No Wayland socket found under $RUNTIME_DIR" >&2
  exit 1
fi

WAYLAND_DISPLAY=$(basename "$SOCKET_PATH")
echo "[test] Found Wayland socket: $SOCKET_PATH (DISPLAY=$WAYLAND_DISPLAY)"

# 3) Export env for Wayland clients
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export WAYLAND_DISPLAY

# 4) Launch Foot as the 'gui' user
echo "[test] Launching foot..."
sudo -u gui foot
