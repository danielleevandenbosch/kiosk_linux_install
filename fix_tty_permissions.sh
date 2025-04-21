#!/usr/bin/env bash
# fix_tty_permissions.sh
# Ensures gui user can write to /dev/tty1 and /dev/dri/card0 permanently

set -euo pipefail

USER=gui
TTY_DEV=/dev/tty1
TTY_UDEV_RULE=/etc/udev/rules.d/99-tty1.rules
GPU_DEV=/dev/dri/card0
GPU_UDEV_RULE=/etc/udev/rules.d/99-gpu.rules

log()
{
    echo -e "[tty-fix] $*"
}

# ── 1. Check if user exists ───────────────────────────────────────
if ! id "$USER" &>/dev/null
then
    log "User '$USER' not found. Aborting."
    exit 1
fi

# ── 2. Add user to tty + video groups if needed ───────────────────
if ! id -nG "$USER" | grep -qw tty
then
    log "Adding '$USER' to group 'tty'"
    usermod -aG tty "$USER"
else
    log "'$USER' is already in 'tty' group"
fi

if ! id -nG "$USER" | grep -qw video
then
    log "Adding '$USER' to group 'video'"
    usermod -aG video "$USER"
else
    log "'$USER' is already in 'video' group"
fi

# ── 3. Fix /dev/tty1 perms live ───────────────────────────────────
if [ -e "$TTY_DEV" ]
then
    log "Fixing current permissions on $TTY_DEV"
    chgrp tty "$TTY_DEV"
    chmod g+rw "$TTY_DEV"
else
    log "$TTY_DEV does not exist yet (maybe not active TTY). Skipping direct chmod."
fi

# ── 4. Fix /dev/dri/card0 perms live ──────────────────────────────
if [ -e "$GPU_DEV" ]
then
    log "Fixing current permissions on $GPU_DEV"
    chgrp video "$GPU_DEV"
    chmod g+rw "$GPU_DEV"
else
    log "$GPU_DEV does not exist yet. Will apply udev rule anyway."
fi

# ── 5. Persistent udev rules ──────────────────────────────────────
log "Writing TTY udev rule to $TTY_UDEV_RULE"
echo 'KERNEL=="tty1", GROUP="tty", MODE="0660"' > "$TTY_UDEV_RULE"

log "Writing GPU udev rule to $GPU_UDEV_RULE"
echo 'KERNEL=="card0", SUBSYSTEM=="drm", GROUP="video", MODE="0660"' > "$GPU_UDEV_RULE"

# ── 6. Reload udev rules ──────────────────────────────────────────
log "Reloading udev rules"
udevadm control --reload
udevadm trigger "$TTY_DEV" || true
udevadm trigger "$GPU_DEV" || true

# ── 7. Show effective permissions ─────────────────────────────────
log "Effective permissions:"
ls -l "$TTY_DEV" 2>/dev/null || true
ls -l "$GPU_DEV" 2>/dev/null || true

log "✅ TTY and GPU permissions set. Reboot recommended to verify."
