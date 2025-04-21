#!/usr/bin/env bash
# fix_tty_permissions.sh
# Ensures gui user can write to /dev/tty1 permanently

set -euo pipefail

USER=gui
TTY_DEV=/dev/tty1
UDEV_RULE=/etc/udev/rules.d/99-tty1.rules

log() {
  echo -e "[tty-fix] $*"
}

# 1. Check if user exists
if ! id "$USER" &>/dev/null; then
  log "User '$USER' not found. Aborting."
  exit 1
fi

# 2. Add user to tty group if needed
if ! id -nG "$USER" | grep -qw tty; then
  log "Adding '$USER' to group 'tty'"
  usermod -aG tty "$USER"
else
  log "'$USER' is already in 'tty' group"
fi

# 3. Set group/permissions on /dev/tty1 right now
if [ -e "$TTY_DEV" ]; then
  log "Fixing current permissions on $TTY_DEV"
  chgrp tty "$TTY_DEV"
  chmod g+rw "$TTY_DEV"
else
  log "$TTY_DEV does not exist yet (maybe not active TTY). Skipping direct chmod."
fi

# 4. Create persistent udev rule
log "Writing udev rule to $UDEV_RULE"
echo 'KERNEL=="tty1", GROUP="tty", MODE="0660"' > "$UDEV_RULE"

# 5. Reload udev rules
log "Reloading udev rules"
udevadm control --reload
udevadm trigger "$TTY_DEV"

log "✅ TTY permissions set. Reboot recommended to verify."
