#!/usr/bin/env bash
set -e
[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }

######## 1. user
id -u gui &>/dev/null || { useradd -m -s /bin/bash gui; echo "gui:gui" | chpasswd; }
usermod -aG dialout gui

######## 2. tty1 autologin
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I $TERM
EOF

######## 3. packages
apt-get update -y
PKG="weston chromium maliit-keyboard"
apt-get install -y $PKG || true   # ignore missing extra deps

command -v chromium >/dev/null || { echo "Chromium missing"; exit 1; }

######## 4. ask res + URL
echo "1)1080p  2)custom"
read -rp "Choose [1]: " CH
if [ "$CH" = 2 ]; then read -rp "WxH: " RES; else RES=1920x1080; fi
read -rp "URL (default https://example.com): " URL
URL=${URL:-https://example.com}
W=${RES%x*}; H=${RES#*x}

######## 5. choose backend
if [ -e /dev/dri/card0 ]; then BACKEND="drm"; else BACKEND="fbdev"; fi

######## 6. start script
sudo -u gui tee /home/gui/start_kiosk_wayland.sh >/dev/null <<EOF
#!/usr/bin/env bash
export XDG_RUNTIME_DIR="/run/user/\$(id -u)"
export QT_QPA_PLATFORM=wayland   # ensure maliit never uses xcb

LOG=/home/gui/weston.log

if [ "$BACKEND" = "drm" ]; then
    if command -v weston-launch >/dev/null; then
        weston-launch -- --width=$W --height=$H --idle-time=0 >"\$LOG" 2>&1 &
    else
        /usr/libexec/weston-launch -- --width=$W --height=$H --idle-time=0 >"\$LOG" 2>&1 &
    fi
else
    dbus-run-session -- \
      weston --backend=fbdev-backend.so --width=$W --height=$H --idle-time=0 >"\$LOG" 2>&1 &
fi

sleep 2
maliit-server &

exec chromium \
  --ozone-platform=wayland \
  --kiosk \
  --no-first-run \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --enable-touch-events \
  "$URL"
EOF

chmod +x /home/gui/start_kiosk_wayland.sh
chown gui:gui /home/gui/start_kiosk_wayland.sh

######## 7. .bash_profile
sudo -u gui tee /home/gui/.bash_profile >/dev/null <<'EOF'
[[ -z $WAYLAND_DISPLAY && $(tty) = /dev/tty1 ]] && /home/gui/start_kiosk_wayland.sh
EOF
chmod 644 /home/gui/.bash_profile

######## 8. restart getty
systemctl daemon-reload
systemctl restart getty@tty1

echo "=============================================="
echo " Wayland kiosk installed"
echo " Backend   : $BACKEND-backend.so"
echo " Resolution: $RES"
echo " URL       : $URL"
echo " Logs      : /home/gui/weston.log"
echo " Reboot or switch to TTY1 to test."
echo "=============================================="
