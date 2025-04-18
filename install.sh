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

PACKAGES=(
  xorg
  chromium
  chromium-browser
  unclutter
  matchbox-window-manager
  onboard
  xdotool
  network-manager
  openssh-client
  openssh-server
  zsh
  vim
  neofetch
  htop
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
  echo "Neither 'chromium' nor 'chromium-browser' is installed or installable. Aborting."
  exit 1
fi

#####################
# 5) Prompt for resolution + URL
#####################
echo "Select a resolution mode for HDMI-1 (common combos):"
echo "1) 1080p (1920x1080)"
echo "2) 4K (3840x2160)"
echo "3) Custom"

read -rp "Enter choice [1-3]: " CHOICE

case "$CHOICE" in
  1) RESOLUTION="1920x1080" ;;
  2) RESOLUTION="3840x2160" ;;
  3)
    read -rp "Enter custom resolution (e.g. 1920x1080): " RESOLUTION
    ;;
  *)
    echo "Invalid choice, defaulting to 1920x1080."
    RESOLUTION="1920x1080"
    ;;
esac

read -rp "Enter the URL to open in Chromium (default: https://example.com): " TARGET_URL
TARGET_URL="${TARGET_URL:-https://example.com}"

#####################
# 6) Create .bash_profile to auto-start X on TTY1
#####################
BASH_PROFILE="/home/gui/.bash_profile"
cat <<'EOF' > "$BASH_PROFILE"
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

chown gui:gui "$BASH_PROFILE"
chmod 644 "$BASH_PROFILE"

#####################
# 7) Create .xinitrc
#####################
XINITRC="/home/gui/.xinitrc"
cat <<EOF > "$XINITRC"
# Disable screen blanking + power management
xset s off -dpms &

# Hide mouse pointer after 300s of inactivity
unclutter -idle 300 &

# Force HDMI-1 to the chosen resolution, disable HDMI-2 (if present)
xrandr \
  --output HDMI-1 --mode ${RESOLUTION} \
  --output HDMI-2 --off &

# Minimal window manager
matchbox-window-manager &

# Launch onboard keyboard watcher
/home/gui/launch_onboard_on_focus.sh &

# Wait a bit to ensure splash is visible
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

chown gui:gui "$XINITRC"
chmod 644 "$XINITRC"

#####################
# 8) Create onboard focus watcher script
#####################
FOCUS_SCRIPT="/home/gui/launch_onboard_on_focus.sh"
cat <<'EOF' > "$FOCUS_SCRIPT"
#!/bin/bash
while true
do
    name=$(xdotool getwindowfocus getwindowname 2>/dev/null)
    if echo "$name" | grep -qiE 'chromium|search|input|form|address'
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
chown gui:gui "$FOCUS_SCRIPT"

#####################
# 9) Reload systemd, restart getty@tty1
#####################
systemctl daemon-reload
systemctl restart getty@tty1

echo "========================================================"
echo "Setup complete!"
echo "TTY1 will auto-login user 'gui'."
echo "Resolution: ${RESOLUTION}"
echo "URL: ${TARGET_URL}"
echo "Using matchbox-window-manager + Chromium kiosk."
echo "Onboard will auto-popup when Chromium input is focused."
echo "========================================================"
