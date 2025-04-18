#!/usr/bin/env bash

# Daniel Van Den Bosch Kiosk Linux Install Script
# https://github.com/danielleevandenbosch/kiosk_linux_install

# Ensure we run as root
if [ "$(id -u)" -ne 0 ]
then
  echo "Please run this script as root or via sudo."
  exit 1
fi

#####################
# 1) Create user "gui" if missing
#####################
if ! id -u gui >/dev/null 2>&1
then
  useradd -m -s /bin/bash gui
  echo "gui:gui" | chpasswd
fi

# Add gui user to dialout group
usermod -aG dialout gui

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
# 3) Install required packages
#####################
echo "Updating package lists..."
apt-get update -y

PACKAGES=
(
  ,xorg
  ,chromium
  ,chromium-browser
  ,unclutter
  ,openbox
  ,onboard
  ,xdotool
  ,network-manager
  ,openssh-client
  ,openssh-server
  ,zsh
  ,vim
  ,neofetch
  ,htop
)

for pkg in "${PACKAGES[@]}"
do
  if dpkg -s "$pkg" &>/dev/null
  then
    echo "Package '$pkg' is already installed."
  else
    apt-get install -y "$pkg" || echo "Package '$pkg' not found or could not be installed."
  fi
done

#####################
# 4) Determine chromium command
#####################
if dpkg -s chromium &>/dev/null
then
  CHROMIUM_CMD="chromium"
elif dpkg -s chromium-browser &>/dev/null
then
  CHROMIUM_CMD="chromium-browser"
else
  echo "Neither 'chromium' nor 'chromium-browser' is installed. Aborting."
  exit 1
fi

#####################
# 5) Prompt for resolution + URL
#####################
echo "Select a resolution mode for HDMI-1:"
echo "1) 1080p (1920x1080)"
echo "2) 4K (3840x2160)"
echo "3) Custom"

read -rp "Enter choice [1-3]: " CHOICE
case "$CHOICE" in
  1) RESOLUTION="1920x1080" ;;
  2) RESOLUTION="3840x2160" ;;
  3)
    read -rp "Enter custom resolution (e.g. 1280x720): " RESOLUTION
    ;;
  *)
    echo "Invalid choice, defaulting to 1920x1080."
    RESOLUTION="1920x1080"
    ;;
esac

read -rp "Enter URL to open (default: https://example.com): " TARGET_URL
TARGET_URL="${TARGET_URL:-https://example.com}"

#####################
# 6) Create .bash_profile to auto-start X on TTY1
#####################
BASH_PROFILE="/home/gui/.bash_profile"
rm -f "$BASH_PROFILE"
sudo -u gui tee "$BASH_PROFILE" <<'EOF'
clear

cat <<'SPLASH'
  _      _                    _  ___           _
 | |    (_)                  | |/ (_)         | |
 | |     _ _ __  _   ___  __ | ' / _  ___  ___| | __
 | |    | | '_ \| | | \ \/ / |  < | |/ _ \/ __| |/ /
 | |____| | | | | |_| |>  <  | . \| | (_) \__ \   <
 |______|_|_| |_|\__,_/_/\_\ |_|\_\_|\___/|___/_|\_\

Daniel Van Den Bosch Kiosk Linux
https://github.com/danielleevandenbosch/kiosk_linux_install

SPLASH

if command -v acpi >/dev/null && command -v figlet >/dev/null
then
    echo "battery at: " | figlet
    acpi | grep -oP '[0-9]+%' | figlet
else
    echo "Battery: $(acpi 2>/dev/null | grep -oP '[0-9]+%' || echo 'unknown')"
fi

sleep 30

if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]
then
  startx
fi
EOF
chmod 644 "$BASH_PROFILE"

#####################
# 7) Create .xinitrc (replace any existing)
#####################
XINITRC="/home/gui/.xinitrc"
rm -f "$XINITRC"
sudo -u gui tee "$XINITRC" <<EOF
# Disable screen blanking + power management
xset s off -dpms &

# Hide mouse pointer after 300s of inactivity
unclutter -idle 300 &

# Force HDMI-1 resolution, disable HDMI-2
xrandr \
  --output HDMI-1 --mode ${RESOLUTION} \
  --output HDMI-2 --off &

# Start Openbox
openbox-session &

# Delay then launch onboard focus‑watcher
(sleep 5 && /home/gui/launch_onboard_on_focus.sh) &

# Wait a bit for splash
sleep 3

# Launch Chromium in kiosk mode
${CHROMIUM_CMD} \
  --kiosk \
  --no-first-run \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --enable-touch-events \
  ${TARGET_URL}
EOF
chmod 644 "$XINITRC"

#####################
# 8) Create onboard focus watcher (replace any existing)
#####################
FOCUS_SCRIPT="/home/gui/launch_onboard_on_focus.sh"
rm -f "$FOCUS_SCRIPT"
sudo -u gui tee "$FOCUS_SCRIPT" <<'EOF'
#!/bin/bash
while true
do
    name=\$(xdotool getwindowfocus getwindowname 2>/dev/null)
    if echo "\$name" | grep -qiE 'chromium|search|input|form|address'
    then
        if ! pgrep -x onboard >/dev/null
        then
            onboard &
        fi
    else
        pkill onboard
    fi
    sleep 1
done
EOF
chmod +x "$FOCUS_SCRIPT"

#####################
# 9) Reload systemd, restart getty@tty1
#####################
systemctl daemon-reload
systemctl restart getty@tty1

echo "========================================================"
echo "Setup complete!"
echo "Auto-login: gui on TTY1"
echo "Resolution: ${RESOLUTION}"
echo "URL: ${TARGET_URL}"
echo "Window manager: Openbox"
echo "Chromium in kiosk + touch enabled"
echo "Onboard auto-popup when Chromium inputs are focused"
echo "========================================================"

