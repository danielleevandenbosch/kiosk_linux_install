#!/usr/bin/env bash
# kiosk_start.sh — unified Wayland kiosk launcher
#
# Usage (as root):
#   kiosk_start.sh                # → launches 'foot'
#   kiosk_start.sh leafpad        # → launches 'leafpad'
#   kiosk_start.sh flatpak run org.chromium.Chromium --ozone-platform=wayland  # Chromium

set -euo pipefail

GUI=gui
GUI_UID=$(id -u "$GUI")
RUNDIR="/run/user/$GUI_UID"
SOCK=wayland-0
WESTON_ARGS=(--backend=drm-backend.so --idle-time=0 --socket="$SOCK" --debug)
CLIENT_CMD=( "${@:-foot}" )

log(){ echo "[kiosk] $*"; }

# 1) Prepare runtime dir
log "Ensuring runtime dir $RUNDIR"
mkdir -p "$RUNDIR"
chown "$GUI:$GUI" "$RUNDIR"
chmod 700 "$RUNDIR"

# 2) Disable system seatd (we’ll use seatd-launch)
log "Stopping and disabling seatd.service"
systemctl stop seatd.service 2>/dev/null || true
systemctl disable seatd.service 2>/dev/null || true

# 3) Start Weston under seatd-launch
if ! pgrep -u "$GUI_UID" -x weston >/dev/null; then
  log "Launching Weston via seatd-launch as $GUI"
  sudo -u "$GUI" env XDG_RUNTIME_DIR="$RUNDIR" \
    seatd-launch weston "${WESTON_ARGS[@]}" \
    >>"$RUNDIR"/weston.log 2>&1 &
  sleep 1
else
  log "Weston already running"
fi

# 4) Wait for the Wayland socket
log "Waiting for Wayland socket ($SOCK)…"
for i in {1..20}; do
  if [ -S "$RUNDIR/$SOCK" ]; then
    log "Found socket: $SOCK"
    break
  fi
  sleep 0.5
  [ "$i" -eq 20 ] && { log "❌ Socket never appeared"; exit 1; }
done

# 5) Launch your client under the same seatd session
log "Launching client as $GUI: ${CLIENT_CMD[*]}"
sudo -u "$GUI" env \
  XDG_RUNTIME_DIR="$RUNDIR" \
  WAYLAND_DISPLAY="$SOCK" \
  seatd-launch "${CLIENT_CMD[@]}"

