#!/usr/bin/env bash
# enable_gui_reboot.sh
# Allows user 'gui' to run reboot without sudo password

set -euo pipefail

log()
{
  echo -e "[reboot-permission] $*"
}

SUDOERS_FILE="/etc/sudoers.d/99-gui-reboot"

log "Granting gui permission to run reboot without password..."

echo "gui ALL=(ALL) NOPASSWD: /sbin/reboot, /usr/sbin/reboot, /bin/systemctl reboot, /usr/bin/systemctl reboot" > "$SUDOERS_FILE"

chmod 440 "$SUDOERS_FILE"
log "✅ Sudoers rule created at $SUDOERS_FILE"
