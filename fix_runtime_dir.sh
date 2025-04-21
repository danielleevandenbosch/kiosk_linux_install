#!/usr/bin/env bash
# fix_runtime_dir.sh
# Ensures /run/user/1001 exists and is properly owned by gui
# Required for Wayland-based sessions to initialize cleanly under a non-root user like 'gui'

set -euo pipefail

USER=gui
UID=1001
RUNTIME_DIR="/run/user/$UID"

log() {
  echo -e "[runtime-fix] $*"
}

# ----------------------------------------------------------------------
# Why this is necessary:
# Wayland expects a per-user runtime directory (typically /run/user/<UID>)
# where it can store session-related sockets, such as the 'wayland-0' socket.
#
# Normally, systemd-logind creates this directory when the user logs in via
# a display manager or loginctl (PAM session), but in a minimal kiosk setup
# where you're auto-logging into TTY1 without systemd's full login stack,
# it doesn't get created automatically.
#
# Without this, Weston will fail to launch with errors like:
#   "Failed to create display: Broken pipe"
#   or
#   "Unable to bind to /run/user/<UID>/wayland-0"
# ----------------------------------------------------------------------

# 1. Create the runtime directory if it doesn't exist
if [ ! -d "$RUNTIME_DIR" ]; then
  log "Creating $RUNTIME_DIR"
  mkdir -p "$RUNTIME_DIR"
fi

# 2. Set proper ownership so that the 'gui' user has access
# This is crucial because Weston will drop privileges and try to write
# files (like the display socket) into this directory.
log "Setting ownership and permissions on $RUNTIME_DIR"
chown "$USER:$USER" "$RUNTIME_DIR"

# 3. Ensure directory is private to the user
# The standard permission for /run/user/<UID> is 0700 — readable and writable only by the owner.
chmod 700 "$RUNTIME_DIR"

log "✅ Runtime directory $RUNTIME_DIR fixed."
