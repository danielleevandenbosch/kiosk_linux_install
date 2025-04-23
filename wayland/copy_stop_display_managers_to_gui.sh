#!/usr/bin/env bash
# copy_stop_display_managers_to_gui.sh
# Copies stop_display_managers.sh into /home/gui with correct permissions

set -euo pipefail

SOURCE="./stop_display_managers.sh"
DEST="/home/gui/stop_display_managers.sh"

log() {
  echo -e "[copy-stop-dm] $*"
}

# Ensure source file exists
if [ ! -f "$SOURCE" ]; then
  log "❌ Source file $SOURCE not found"
  exit 1
fi

# Ensure user gui exists
if ! id gui &>/dev/null; then
  log "❌ User 'gui' does not exist"
  exit 1
fi

cp "$SOURCE" "$DEST"
chmod +x "$DEST"
chown gui:gui "$DEST"

log "✅ Copied stop_display_managers.sh to $DEST with correct ownership and permissions"
