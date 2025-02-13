#!/usr/bin/env bash

# Ensure we are running as root
if [ "$(id -u)" -ne 0 ]
then
  echo "Please run this script as root or via sudo."
  exit 1
fi

# 1. Create user 'gui' with password 'gui' if it doesn't exist
if ! id -u gui >/dev/null 2>&1
then
  useradd -m -s /bin/bash gui
  echo "gui:gui" | chpasswd
fi

# 2. Restore default getty@.service in case it's been modified (optional step).
#    Remove or comment out if you're certain your base file is stock.
#    The typical default ExecStart line is:
#    ExecStart=-/sbin/agetty -o '-p -- \u' --noclear %I $TERM
# cp /usr/lib/systemd/system/getty@.service /usr/lib/systemd/system/getty@.service.bak
# <restore from backup or manually fix if needed>

# 3. Create override for auto-login on tty1 only
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOF > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I \$TERM
EOF

# 4. Install packages (Xorg, Chromium, Unclutter).  Adjust package names if needed.
PACKAGES=(
, "xorg"
, "chromium-browser"
, "unclutter"
)
apt-get update -y
apt-get install -y "${PACKAGES[@]}"

# 5. Configure 'gui' user to automatically start X on tty1:
#    We'll use ~/.bash_profile. If GUI's default shell is zsh, you'd do ~/.zlogin instead.

BASH_PROFILE="/home/gui/.bash_profile"

cat <<EOF > "\${BASH_PROFILE}"
if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]
then
  startx
fi
EOF

chown gui:gui "\${BASH_PROFILE}"

# 6. Create ~/.xinitrc for the 'gui' user to launch Chromium fullscreen
XINITRC="/home/gui/.xinitrc"

cat <<'EOF' > "\${XINITRC}"
xset s off -dpms &
unclutter -idle 300 &
xrandr --output "HDMI-1" --auto --output "HDMI-2" --same-as "HDMI-1" &
sleep 5
chromium-browser --start-fullscreen --disable-session-crashed-bubble --disable-infobars --incognito http://10.20.0.219/
EOF

chown gui:gui "\${XINITRC}"

# 7. Reload systemd and restart getty@tty1
systemctl daemon-reload
systemctl restart getty@tty1

echo "All done!  Autologin on tty1 for user 'gui' with fullscreen Chromium is configured."
echo "Reboot or switch to tty1 (Ctrl+Alt+F1) to test."