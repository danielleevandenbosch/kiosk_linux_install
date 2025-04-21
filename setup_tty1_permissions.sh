#!/usr/bin/env bash
# setup_tty1_permissions.sh — ensure tty1 is accessible to gui user

echo "[tty-perms] Writing udev rule for /dev/tty1..."

cat >/etc/udev/rules.d/81-tty1.rules <<'EOF'
KERNEL=="tty1", GROUP="tty", MODE="0660"
EOF

udevadm control --reload-rules
udevadm trigger /dev/tty1

echo "[tty-perms] /dev/tty1 permission rule applied."
