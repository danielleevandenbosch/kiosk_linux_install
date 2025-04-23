#!/usr/bin/env bash
# fix_runtime_dir.sh
# Ensures /run/user/<UID> exists, is owned by 'gui', and has proper permissions.
# Wayland compositors like Weston depend on this directory to bind IPC sockets.

set -euo pipefail

USER=gui

log()
{
    echo -e "[runtime-fix] $*"
}

# 0. Ensure we're running as root
if [[ "$(id -u)" -ne 0 ]]; then
  log "❌ This script must be run as root."
  exit 1
fi

# 1. Ensure the user exists
if ! id "$USER" &>/dev/null; then
  log "❌ User '$USER' does not exist. Aborting."
  exit 1
fi

# 2. Get the UID for the user
USER_UID=$(id -u "$USER")
RUNTIME_DIR="/run/user/$USER_UID"

log "📦 Preparing runtime dir for user '$USER' (UID=$USER_UID)"

# 3. Create the runtime directory if missing
if [ ! -d "$RUNTIME_DIR" ]; then
  log "🛠️  Creating $RUNTIME_DIR"
  mkdir -p "$RUNTIME_DIR"
else
  log "✔ $RUNTIME_DIR already exists"
fi

# 4. Ensure correct ownership
log "🔐 Assigning ownership: $USER:$USER"
chown "$USER:$USER" "$RUNTIME_DIR"

# 5. Set proper permissions
log "🔒 Setting permissions to 0700"
chmod 0700 "$RUNTIME_DIR"

# 6. Check writability by user
if ! sudo -u "$USER" test -w "$RUNTIME_DIR"; then
  log "⚠️  '$USER' does NOT have write access to $RUNTIME_DIR!"
  ls -ld "$RUNTIME_DIR"
  exit 1
fi

# 7. Ensure XDG_RUNTIME_DIR is exported in the user’s environment
USER_PROFILE="/home/$USER/.bash_profile"
if ! sudo -u "$USER" grep -q "XDG_RUNTIME_DIR=" "$USER_PROFILE" 2>/dev/null; then
  log "📎 Appending XDG_RUNTIME_DIR to $USER_PROFILE"
  echo "export XDG_RUNTIME_DIR=/run/user/$USER_UID" >> "$USER_PROFILE"
else
  log "✔ XDG_RUNTIME_DIR already exported in $USER_PROFILE"
fi

# 8. Print summary for diagnostics
log "✅ Runtime directory setup complete:"
log "  → Path: $RUNTIME_DIR"
log "  → Owner: $(stat -c %U:%G "$RUNTIME_DIR")"
log "  → Permissions: $(stat -c %a "$RUNTIME_DIR")"
