#!/usr/bin/env bash

### scripts/07_write_xinitrc.sh
cat <<EOF > /home/gui/.xinitrc
xset s off -dpms &
unclutter -idle 300 &
xrandr \
  --output HDMI-1 --mode ${RESOLUTION} \
  --output HDMI-2 --off &
matchbox-window-manager &
sleep 3
${CHROMIUM_CMD} \
  --kiosk \
  --no-first-run \
  --disable-infobars \
  --disable-session-crashed-bubble \
  ${TARGET_URL}
EOF

chown gui:gui /home/gui/.xinitrc
chmod 644 /home/gui/.xinitrc