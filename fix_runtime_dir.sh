#!/usr/bin/env bash
# fix_runtime_dir.sh
# Ensures /run/user/1001 exists and is properly owned by gui

set -euo pipefail

USER=gui
UID=1001
RUNTIME_DIR="/run/user/$UID"

log() {
  echo -e "[runtime-fix] $*"
}

# 1. Create the runtime directory if it doesn't exist
if [ ! -d "$RUNTIME_DIR" ]; then
  log "Creating $RUNTIME_DIR"
  mkdir -p "$RUNTIME_DIR"
fi

# 2. Set ownership and permissions
log "Setting ownership and permissions on $RUNTIME_DIR"
chown "$USER:$USER" "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR"

log "✅ Runtime directory $RUNTIME_DIR fixed."
