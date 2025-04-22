#!/usr/bin/env bash
# test_foot.sh
# -----------------------------------------------------------------------------
# Test launching the Wayland terminal emulator `foot` in a Weston session.
# This script:
#   - Detects the correct WAYLAND_DISPLAY socket
#   - Ensures XDG_RUNTIME_DIR is set
#   - Logs output and errors for diagnostics
# -----------------------------------------------------------------------------

set -euo pipefail

USER_UID=1001
XDG_RUNTIME_DIR="/run/user/$USER_UID"
LOGFILE="$HOME/foot_test.log"

# Function to log with prefix
log() {
  echo -e "[foot-test] $*" | tee -a "$LOGFILE"
}

# Clear previous log
: > "$LOGFILE"

log "👣 Starting test_foot.sh"
log "🧪 Checking for Weston sockets under $XDG_RUNTIME_DIR..."

# Try to find a valid WAYLAND_DISPLAY socket (e.g., wayland-0 or wayland-1)
SOCKET=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -type=s -name 'wayland-*' | head -n 1)

if [ -z "$SOCKET" ]; then
  log "❌ No wayland socket found in $XDG_RUNTIME_DIR"
  exit 1
fi

WAYLAND_DISPLAY=$(basename "$SOCKET")
log "✅ Found display socket: $WAYLAND_DISPLAY"

# Export required environment variables
export XDG_RUNTIME_DIR
export WAYLAND_DISPLAY

log "🚀 Launching foot with:"
log "    XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
log "    WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
log "    Command: foot"

# Launch foot and capture any errors
if foot >>"$LOGFILE" 2>&1; then
  log "✅ foot launched successfully"
else
  log "❌ foot failed to launch — see log above"
  exit 1
fi
