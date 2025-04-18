#!/usr/bin/env bash
# Daniel Van Den Bosch — kiosk_linux_install
# (continues even when some packages can’t be installed)

# must run as root
if [ "$(id -u)" -ne 0 ]
then
  echo "Run this script as root (sudo)."
  exit 1
fi

#####################
# 1) create gui user
#####################
if ! id -u gui >/dev/null 2>&1
then
  useradd -m -s /bin/bash gui
  echo "gui:gui" | chpasswd
fi
usermod -aG dialout gui

#####################
# 2) autologin on tty1
#####################
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOF > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I \$TERM
EOF

#####################
# 3) install packages
#####################
echo "Updating apt lists..."
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
    echo "Package '$pkg' already installed."
  else
    echo "Installing $pkg …"
    apt-get install -y "$pkg" \
      || echo "⚠️  Package '$pkg' not available—continuing."
  fi
done

#####################
# 4) find chromium binary
#####################
if command -v chromium >/dev/null
then
  CHROME_CMD="chromium"
elif command -v chromium-browser >/dev/null
then
  CHROME_CMD="chromium-browser"
else
  echo "❌ Neither 'chromium' nor 'chromium-browser' is installed. Exiting."
  exit 1
fi

#####################
# 5) resolution + URL
#####################
echo "Select HDMI‑1 resolution:"
echo "1) 1080p   2) 4K   3) custom"
read -rp "Choice [1‑3]: " CHOICE
case "$CHOICE" in
  1) RESOLUTION="1920x1080" ;;
  2) RESOLUTION="3840x2160" ;;
  3) read -rp "Custom resolution: " RESOLUTION ;;
  *) RESOLUTION="1920x1080" ;;
esac

read -rp "URL to open (default https://example.com): " TARGET_URL
TARGET_URL="${TARGET_URL:-https://example.com}"

#####################
# 6) .bash_profile
#####################
sudo -u gui tee /home/gui/.bash_profile >/dev/null <<'EOF'
clear
echo "Kiosk booting…"
sleep 30
if [[ -z $DISPLAY && $(tty) = /dev/tty1 ]]; then startx; fi
EOF
chmod 644 /home/gui/.bash_profile

#####################
# 7) .xinitrc
#####################
sudo -u gui tee /home/gui/.xinitrc >/dev/null <<EOF
# disable blanking
xset s off -dpms &

# hide pointer
unclutter -idle 300 &

# set resolution
xrandr --output HDMI-1 --mode ${RESOLUTION} --output HDMI-2 --off &

# window manager
matchbox-window-manager &

# launch watcher after 5 s
(sleep 5 && /home/gui/launch_onboard_on_focus.sh) &

# splash delay
sleep 3

# run chromium in foreground
exec ${CHROME_CMD} \
  --kiosk \
  --no-first-run \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --enable-touch-events \
  "${TARGET_URL}"
EOF
chmod 644 /home/gui/.xinitrc

#####################
# 8) focus‑watcher
#####################
sudo -u gui tee /home/gui/launch_onboard_on_focus.sh >/dev/null <<'EOF'
#!/bin/bash
LOG=/home/gui/onboard-focus.log
echo "===== watcher start $(date) =====" > "$LOG"

while true
do
  class=$(xdotool getwindowfocus getwindowclassname 2>/dev/null)
  title=$(xdotool getwindowfocus getwindowname     2>/dev/null)
  echo "$(date +%T)  class:<$class> title:<$title>" >> "$LOG"

  if echo "$class" | grep -qi chromium
  then
      pgrep -x onboard >/dev/null || { echo "$(date +%T) launching"; onboard & }
  else
      pkill onboard 2>/dev/null && echo "$(date +%T) killing onboard" >> "$LOG"
  fi
  sleep 1
done
EOF
chmod +x /home/gui/launch_onboard_on_focus.sh

#####################
# 9) reload getty
#####################
systemctl daemon-reload
systemctl restart getty@tty1

echo "========================================="
echo "Setup complete!"
echo "User auto‑login : gui"
echo "Resolution      : $RESOLUTION"
echo "URL             : $TARGET_URL"
echo "Chromium binary : $CHROME_CMD"
echo "On‑screen keyboard will auto‑popup."
echo "Focus log       : /home/gui/onboard-focus.log"
echo "========================================="
