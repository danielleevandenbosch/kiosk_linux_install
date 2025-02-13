#!/usr/bin/env bash

#
# setup_autologin_browser.sh
# 
# Interactive script:
#   { Creates user "gui" if not present (pw: "gui") }
#   { Installs xorg, chromium-browser, unclutter }
#   { Sets up auto-login on TTY1 for "gui" }
#   { Prompts for resolution + scale + URL }
#   { Writes .bash_profile + .xinitrc properly }
#

# Ensure we are running as root
if [ "$(id -u)" -ne 0 ]
then
  echo "Please run this script as root or via sudo."
  exit 1
fi

#####################
# 1) Create "gui" user if missing
#####################
if ! id -u gui >/dev/null 2>&1
then
  useradd -m -s /bin/bash gui
  echo "gui:gui" | chpasswd
fi

#####################
# 2) Setup auto-login on tty1 for "gui"
#####################
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOF > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I \$TERM
EOF

#####################
# 3) Install packages
#####################
PACKAGES=(
, "xorg"
, "chromium-browser"
, "unclutter"
)

apt-get update -y
apt-get install -y "${PACKAGES[@]}"

#####################
# 4) Prompt for resolution/scale/URL
#####################
echo "Select a resolution/scale option:"
echo "1) 1080p native (1920x1080, scale 1x1)"
echo "2) 4K -> 1080p (3840x2160, scale 0.5x0.5)"
echo "3) Custom"

read -rp "Enter choice [1-3]: " CHOICE

case "$CHOICE" in
  1)
    RESOLUTION="1920x1080"
    SCALE="1x1"
    ;;
  2)
    RESOLUTION="3840x2160"
    SCALE="0.5x0.5"
    ;;
  3)
    read -rp "Enter custom resolution (e.g., 1920x1080): " RESOLUTION
    read -rp "Enter custom scale factor (e.g., 1x1 or 0.25x0.5): " SCALE
    ;;
  *)
    echo "Invalid choice, defaulting to 1920x1080 scale=1x1."
    RESOLUTION="1920x1080"
    SCALE="1x1"
    ;;
esac

read -rp "Enter the URL to open in Chromium (default: https://example.com): " TARGET_URL
if [ -z "$TARGET_URL" ]
then
  TARGET_URL="https://example.com"
fi

#####################
# 5) Create .bash_profile (auto-start X on TTY1)
#####################
BASH_PROFILE="/home/gui/.bash_profile"
cat <<EOF > "$BASH_PROFILE"
if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]
then
  startx
fi
EOF

chown gui:gui "$BASH_PROFILE"
chmod 644 "$BASH_PROFILE"

#####################
# 6) Create .xinitrc with xrandr + Chromium
#####################
XINITRC="/home/gui/.xinitrc"
cat <<EOF > "$XINITRC"
# Turn off screen blanking + power management
xset s off -dpms &

# Hide mouse pointer after 300s of inactivity
unclutter -idle 300 &

# Set resolution + scale on HDMI-1 (disable or mirror other outputs as desired)
xrandr \\
  --output HDMI-1 --mode ${RESOLUTION} --scale ${SCALE} \\
  --output HDMI-2 --off &

sleep 5

chromium-browser \\
  --start-fullscreen \\
  --disable-session-crashed-bubble \\
  --disable-infobars \\
  --incognito \\
  ${TARGET_URL}
EOF

chown gui:gui "$XINITRC"
chmod 644 "$XINITRC"

#####################
# 7) Reload systemd, restart getty@tty1
#####################
systemctl daemon-reload
systemctl restart getty@tty1

echo "========================================================"
echo "Setup complete!"
echo "TTY1 will auto-login user 'gui'."
echo "Resolution: ${RESOLUTION}, Scale: ${SCALE}"
echo "URL: ${TARGET_URL}"
echo "Switch to TTY1 (Ctrl+Alt+F1) or reboot to test."
echo "========================================================"
