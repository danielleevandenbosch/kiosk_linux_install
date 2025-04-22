#!/usr/bin/env bash
#
# kiosk_start.sh — start Weston + a Wayland client in one go
#
# Usage (as root): 
#   kiosk_start.sh                # → runs `foot` by default
#   kiosk_start.sh leafpad        # → runs leafpad
#   kiosk_start.sh flatpak run org.chromium.Chromium --ozone-platform=wayland
#
set -euo pipefail

GUI=gui
GUI_UID=$(id -u "$GUI")                      # avoid shadowing readonly $UID
RUNDIR="/run/user/$GUI_UID"
SOCK=wayland-0
WESTON_ARGS=( --backend=drm-backend.so \
              --idle-time=0 \
              --socket="$SOCK" \
              --debug )

log(){ echo "[kiosk] $*"; }

# 1) make sure the runtime dir exists and is owned correctly
log "Ensuring $RUNDIR exists"
mkdir -p "$RUNDIR"
chown "$GUI:$GUI" "$RUNDIR"
chmod 700 "$RUNDIR"

# 2) launch Weston if not already running
if ! pgrep -u "$GUI_UID" -x weston >/dev/null; then
  log "Starting Weston as $GUI (socket=$SOCK)"
  sudo -u "$GUI" env XDG_RUNTIME_DIR="$RUNDIR" \
    weston "${WESTON_ARGS[@]}" \
    >>"$RUNDIR"/weston.log 2>&1 &
  sleep 0.5
else
  log "Weston already running, skipping start"
fi

# 3) wait for the socket
log "Waiting for Wayland socket ($SOCK)…"
for i in {1..20}; do
  if [ -S "$RUNDIR/$SOCK" ]; then
    log "→ Found $SOCK"
    break
  fi
  sleep 0.25
  [ "$i" -eq 20 ] && { log "❌ socket never appeared"; exit 1; }
done

# 4) pick your client
if [ $# -eq 0 ]; then
  CLIENT=(foot)
else
  CLIENT=("$@")
fi

log "Launching client as $GUI: ${CLIENT[*]}"
sudo -u "$GUI" env \
  XDG_RUNTIME_DIR="$RUNDIR" \
  WAYLAND_DISPLAY="$SOCK" \
  "${CLIENT[@]}"

