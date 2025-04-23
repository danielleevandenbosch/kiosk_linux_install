#!/usr/bin/env bash

### scripts/08_finalize_setup.sh
systemctl daemon-reload
systemctl restart getty@tty1

echo "========================================================"
echo "Setup complete!"
echo "TTY1 will auto-login user 'gui'."
echo "Resolution: ${RESOLUTION}"
echo "URL: ${TARGET_URL}"
echo "Using matchbox-window-manager + Chromium kiosk."
echo "Detected Chromium command: ${CHROMIUM_CMD}"
echo "Switch to TTY1 (Ctrl+Alt+F1) or reboot to test."
echo "========================================================"
