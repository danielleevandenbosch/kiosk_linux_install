#!/usr/bin/env bash
# fix_runtime_dir.sh
# Ensures /run/user/<UID> exists and is properly owned by gui
# This directory is required by Wayland/Weston to create session-related sockets

set -euo pipefail

USER=gui
USER_UID=$(id -u "$USER")
RUNTIME_DIR="/run/user/$USER_UID"

log() {
  echo -e "[runtime-fix] $*"
}

# ----------------------------------------------------------------------
# Why this is necessary:
# Wayland compositors like Weston require a user-specific runtime directory
# at /run/user/<UID>, where they place IPC sockets like wayland-0.
#
# This directory is normally created by systemd-logind during a PAM session
# (e.g., when using a full display manager). But in minimal setups that auto-login
# on tty1 without systemd-logind involvement, it doesn't get created.
#
# Without this, Weston fails to start with:
#   "Failed to create display: Broken pipe"
#   "Unable to bind to /run/user/<UID>/wayland-0"
# ----------------------------------------------------------------------

# 1. Create runtime directory if needed
if [ ! -d "$RUNTIME_DIR" ]; then
  log "Creating $RUNTIME_DIR (likely not created by systemd)"
  mkdir -p "$RUNTIME_DIR"
else
  log "$RUNTIME_DIR already exists"
fi

# 2. Set ownership and permissions
log "Assigning $USER:$USER ownership to $RUNTIME_DIR"
chown "$USER:$USER" "$RUNTIME_DIR"

log "Setting 0700 permissions to restrict access"
chmod 700 "$RUNTIME_DIR"

# 3. Confirm write access
if ! sudo -u "$USER" test -w "$RUNTIME_DIR"; then
  log "⚠️  Warning: $USER does not have write access to $RUNTIME_DIR"
  exit 1
fi

# 4. Optional: Check XDG_RUNTIME_DIR is set
if ! sudo -u "$USER" env | grep -q XDG_RUNTIME_DIR; then
  log "⚠️  Note: XDG_RUNTIME_DIR is not set for user '$USER'."
  log "You'll want to export it to $RUNTIME_DIR in your environment before launching Weston."
fi

log "✅ Runtime directory $RUNTIME_DIR is properly configured."
