#!/usr/bin/env bash
# Daniel Van Den Bosch — kiosk_linux_install

set -e

# ──────────────────────────────────── 0. must run as root
if [ "$(id -u)" -ne 0 ]
then
    echo "Run as root or via sudo."
    exit 1
fi

# ──────────────────────────────────── 1. create gui user
if ! id -u gui >/dev/null 2>&1
then
    useradd -m -s /bin/bash gui
    echo "gui:gui" | chpasswd
fi
usermod -aG dialout gui

# ──────────────────────────────────── 2. autologin on tty1
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOF > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I \$TERM
EOF

# ──────────────────────────────────── 3. packages
echo "Updating apt lists…"
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
for p in "${PACKAGES[@]}"
do
    dpkg -s "$p" &>/dev/null || apt-get install -y "$p"
done

# ──────────────────────────────────── 4. chromium binary
if dpkg -s chromium &>/dev/null
then CHROME=chromium
elif dpkg -s chromium-browser &>/dev/null
then CHROME=chromium-browser
else echo "Chromium not found"; exit 1
fi

# ──────────────────────────────────── 5. resolution + URL
echo "1) 1080p  2) 4K  3) custom"
read -rp "Choose [1‑3]: " C
case $C in
  1) RES=1920x1080 ;;
  2) RES=3840x2160 ;;
  3) read -rp "Resolution: " RES ;;
  *) RES=1920x1080 ;;
esac
read -rp "URL (default https://example.com): " URL
URL=${URL:-https://example.com}

# ──────────────────────────────────── 6. .bash_profile
sudo -u gui tee /home/gui/.bash_profile >/dev/null <<'EOF'
clear
echo "Kiosk booting…"
sleep 30
if [[ -z $DISPLAY && $(tty) = /dev/tty1 ]]; then startx; fi
EOF
chmod 644 /home/gui/.bash_profile

# ──────────────────────────────────── 7. .xinitrc  (replace)
sudo -u gui tee /home/gui/.xinitrc >/dev/null <<EOF
# disable DPMS / blanking
xset s off -dpms &

# hide pointer after 5 min
unclutter -idle 300 &

# force resolution
xrandr --output HDMI-1 --mode ${RES} --output HDMI-2 --off &

# tiny WM
matchbox-window-manager &

# launch watcher after WM is ready
(sleep 5 && /home/gui/launch_onboard_on_focus.sh) &

# little pause for splash
sleep 3

# foreground chromium
exec ${CHROME} \
  --kiosk \
  --no-first-run \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --enable-touch-events \
  "${URL}"
EOF
chmod 644 /home/gui/.xinitrc

# ──────────────────────────────────── 8. focus watcher  (replace)
sudo -u gui tee /home/gui/launch_onboard_on_focus.sh >/dev/null <<'EOF'
#!/bin/bash
LOG=/home/gui/onboard-focus.log
echo "===== watcher start $(date) =====" > "$LOG"

while true
do
    title=$(xdotool getwindowfocus getwindowname     2>/dev/null)
    class=$(xdotool getwindowfocus getwindowclassname 2>/dev/null)
    echo "$(date +%T)  class:<$class>  title:<$title>" >> "$LOG"

    if echo "$class" | grep -qi chromium
    then
        if ! pgrep -x onboard >/dev/null
        then
            echo "$(date +%T)  launching onboard" >> "$LOG"
            onboard &
        fi
    else
        if pgrep -x onboard >/dev/null
        then
            echo "$(date +%T)  killing onboard" >> "$LOG"
            pkill onboard
        fi
    fi
    sleep 1
done
EOF
chmod +x /home/gui/launch_onboard_on_focus.sh

# ──────────────────────────────────── 9. reload getty
systemctl daemon-reload
systemctl restart getty@tty1

echo "===== Setup complete ====="
echo "Auto‑login user: gui"
echo "Resolution       : $RES"
echo "URL              : $URL"
echo "Matchbox + Chromium kiosk with auto onscreen keyboard"
echo "Watcher logs at  : /home/gui/onboard-focus.log"


