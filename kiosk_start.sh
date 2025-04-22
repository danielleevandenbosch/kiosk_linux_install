#!/usr/bin/env bash
#
# kiosk_start.sh — unified launcher for Wayland kiosk
#
# 1. Ensure /run/user/<UID> exists and is owned by gui
# 2. Start Weston as user 'gui' (if not already running)
# 3. Wait for the Wayland socket to appear
# 4. Launch a Wayland client (foot by default) as gui
#
# Usage (as root):  kiosk_start.sh [app_cmd...]
#    If you pass positional args, they become the client command.
#    e.g. kiosk_start.sh flatpak run org.chromium.Chromium --ozone-platform=wayland
#

set -euo pipefail

GUI_USER=gui
GUI_UID=$(id -u "$GUI_USER")
RUNTIME_DIR="/run/user/$GUI_UID"
WAYLAND_SOCKET_NAME="wayland-0"    # fixed name for weston
WESTON_ARGS=(--backend=drm-backend.so --idle-time=0 --socket="$WAYLAND_SOCKET_NAME" --debug)

log() { echo "[kiosk] $*"; }

# ─── 1. Fix up runtime dir ───────────────────────────────────────────────
log "Checking runtime directory: $RUNTIME_DIR"
if [ ! -d "$RUNTIME_DIR" ]; then
  log "Creating $RUNTIME_DIR"
  mkdir -p "$RUNTIME_DIR"
fi
log "Setting owner to $GUI_USER:$GUI_USER and mode 0700"
chown "$GUI_USER:$GUI_USER" "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR"

# ─── 2. Launch Weston if needed ─────────────────────────────────────────
# check if weston already running under gui
if ! pgrep -u "$GUI_UID" -x weston >/dev/null; then
  log "Starting Weston as $GUI_USER..."
  sudo -u "$GUI_USER" env XDG_RUNTIME_DIR="$RUNTIME_DIR" \
    weston "${WESTON_ARGS[@]}" >> "$RUNTIME_DIR"/weston.log 2>&1 &
  log "Weston PID=$!"
else
  log "Weston already running."
fi

# ─── 3. Wait for the socket ──────────────────────────────────────────────
log "Waiting for Wayland socket…"
for i in {1..10}; do
  if [ -S "$RUNTIME_DIR/$WAYLAND_SOCKET_NAME" ]; then
    log "Found socket: $WAYLAND_SOCKET_NAME"
    break
  fi
  sleep 0.5
  [ "$i" -eq 10 ] && { log "❌ socket never appeared"; exit 1; }
done

# ─── 4. Launch your client as gui ────────────────────────────────────────
# default to foot if no args passed
if [ $# -eq 0 ]; then
  CLIENT_CMD=(foot)
else
  CLIENT_CMD=("$@")
fi

log "Launching client: ${CLIENT_CMD[*]}"
sudo -u "$GUI_USER" env \
  XDG_RUNTIME_DIR="$RUNTIME_DIR" \
  WAYLAND_DISPLAY="$WAYLAND_SOCKET_NAME" \
  "${CLIENT_CMD[@]}"
