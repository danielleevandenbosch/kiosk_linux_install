#!/usr/bin/env bash
# generate_weston_ini.sh
# Creates ~/.config/weston.ini for the 'gui' user with keyboard config

set -euo pipefail

KEYBD=$(dpkg -L weston | grep -m1 weston-keyboard) || {
  echo "❌ weston-keyboard not found" >&2
  exit 1
}

sudo -u gui mkdir -p /home/gui/.config
cat > /home/gui/.config/weston.ini <<EOF
[core]
idle-time=0

[keyboard]
command=$KEYBD
EOF

chown gui:gui /home/gui/.config/weston.ini
chmod 644 /home/gui/.config/weston.ini
