#!/usr/bin/env bash
# setup_autologin_tty1.sh
# Configures TTY1 to auto-login as "gui" user

set -euo pipefail

log() {
  echo -e "[autologin-setup] $*"
}

log "Creating systemd override directory..."
mkdir -p /etc/systemd/system/getty@tty1.service.d

log "Writing autologin override file..."
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I $TERM
EOF

log "Reloading systemd daemon..."
systemctl daemon-reexec || true

log "Autologin on TTY1 configured for user 'gui'."
