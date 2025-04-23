#!/usr/bin/env bash
# install_complete_message.sh
# Final step: reload systemd and print completion instructions

set -euo pipefail

WESTON_BIN=${1:-"/usr/bin/weston-launch"}

echo "[finisher] Reloading systemd daemon..."
systemctl daemon-reload
systemctl restart getty@tty1

cat <<EOF

===== INSTALL COMPLETE – REBOOT NOW =====
• Weston will launch via $WESTON_BIN
• Logs will appear in /home/gui/kiosk-weston.log
• If it fails: last 60 lines dump to tty1
EOF
