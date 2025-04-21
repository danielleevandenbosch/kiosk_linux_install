#!/usr/bin/env bash
# install_wayland.sh
# Master Wayland-only kiosk ricer, calls dependency script first

set -euo pipefail
INSTALL_LOG=/var/log/kiosk_install.log
exec > >(tee -a "$INSTALL_LOG") 2>&1

log() { echo -e "[installer] $*"; }
die() { echo "❌  $*"; exit 1; }
pkg() { dpkg -s "$1" &>/dev/null || apt-get install -y "$1" || die "pkg $1"; }
as_gui() { sudo -u gui bash -c "$*"; }

[ "$(id -u)" -eq 0 ] || die "Run as root."

log "Calling dependency installer..."
bash ./install_wayland_dependancies.sh || die "Dependency script failed."


# ── 0. Stop conflicting display managers ──────────────────────────────
bash ./stop_display_managers.sh || die "Failed to stop display managers"

# ── 1. user gui ────────────────────────────────────────────────────
id -u gui &>/dev/null || { useradd -m -s /bin/bash gui; echo gui:gui | chpasswd; }
usermod -aG dialout,video gui

# ── 1.5. TTY permissions ───────────────────────────────────────────
bash ./fix_tty_permissions.sh || die "Failed to set TTY permissions"

# ── 1.6. Copy stop_display_managers.sh to gui ──────────────────────
bash ./copy_stop_display_managers_to_gui.sh || die "Failed to copy display manager script"


# ── 2. autologin tty1 ───────────────────────────────────────────
bash ./setup_autologin_tty1.sh || die "Autologin setup failed."


# ── 3. weston-launch detection ───────────────────────────────────────────
WESTON_LAUNCH_BIN="$(bash ./weston_check.sh)"
chmod u+s "$WESTON_LAUNCH_BIN"
echo "• Using weston-launch: $WESTON_LAUNCH_BIN"

# ── 4. prompt ──────────────────────────────────────────────
eval "$(bash ./get_kiosk_input.sh)" || die "Invalid input"
echo "• Using resolution ${W}x${H}, URL=$URL"


# ── 5. weston.ini ────────────────────────────────────────
bash ./generate_weston_ini.sh || die "Failed to create weston.ini"

# ── 6. start_kiosk.sh ────────────────────────────────────────
bash ./generate_start_kiosk.sh "$W" "$H" "$URL" "$WESTON_LAUNCH_BIN"

# ── 7. bash_profile ────────────────────────────────────────
bash ./generate_bash_profile.sh || die "Failed to write .bash_profile"

# ── 8. check_weston_backend ────────────────────────────────────────
log "Checking DRM backend availability..."
bash ./check_weston_backend.sh || die "Backend check failed"

# ── 9. finish ────────────────────────────────────────
bash ./install_complete_message.sh "$WESTON_LAUNCH_BIN"

