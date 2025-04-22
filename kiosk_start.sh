#!/usr/bin/env bash
# kiosk_start.sh — start Weston + client in one go, without seatd

set -euo pipefail
LOGDIR=/run/user/1001
LOGFILE=$LOGDIR/kiosk.log
USER=gui
UID=1001
WAYLAND_SOCKET=wayland-0

CLIENT=( "${@:-foot}" )

log() { echo "[kiosk] $*"; }

# 1) Prep the runtime dir
log "Preparing $LOGDIR"
mkdir -p "$LOGDIR"
chown "$USER:$USER" "$LOGDIR"
chmod 700 "$LOGDIR"

# 2) Clear last run log
: > "$LOGFILE"
chmod 664 "$LOGFILE"

# 3) Launch Weston as gui
log "Launching Weston as $USER"
sudo -u "$USER" env \
    XDG_RUNTIME_DIR="$LOGDIR" \
    WESTON_DEBUG=1 \
    weston --backend=drm-backend.so --idle-time=0 --socket="$WAYLAND_SOCKET" \
      >>"$LOGFILE" 2>&1 &

# 4) Wait for wayland-0 socket
log "Waiting for Wayland socket…"
for i in $(seq 1 20); do
  if [ -S "$LOGDIR/$WAYLAND_SOCKET" ]; then
    log "Found socket $WAYLAND_SOCKET"
    break
  fi
  sleep 0.5
  [ "$i" -eq 20 ] && { log "❌ socket never appeared"; exit 1; }
done

# 5) Launch your client under that same RUNTIME_DIR
log "Launching client: ${CLIENT[*]}"
sudo -u "$USER" env \
    XDG_RUNTIME_DIR="$LOGDIR" \
    WAYLAND_DISPLAY="$WAYLAND_SOCKET" \
    "${CLIENT[@]}"
