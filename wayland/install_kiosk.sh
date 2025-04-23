#!/usr/bin/env bash
set -e

# ── root check ─────────────────────────────────────────────
[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)."; exit 1; }

# ── 1. ensure gui user ─────────────────────────────────────
if ! id -u gui >/dev/null 2>&1
then
    useradd -m -s /bin/bash gui
    echo "gui:gui" | chpasswd
fi
usermod -aG dialout gui

# ── 2. autologin on tty1 ───────────────────────────────────
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I $TERM
EOF

# ── 3. packages (ignore missing) ───────────────────────────
apt-get update -y
PKGS=(
  weston
  xserver-xorg
  xinit
  matchbox-window-manager
  maliit-keyboard
  onboard
  xdotool
  chromium
  unclutter
  openssh-server
  zsh
  vim
  htop
  neofetch
)
for p in "${PKGS[@]}"
do
  dpkg -s "$p" &>/dev/null || apt-get install -y "$p" || true
done

command -v chromium >/dev/null || { echo "Chromium missing – abort."; exit 1; }

# ── 4. ask resolution + URL ────────────────────────────────
echo "Resolution options:"
echo " 1) 1920x1080 (1080p)"
echo " 2) 3840x2160 (4K)"
echo " 3) Custom"
read -rp "Choose [1‑3]: " CH
case "$CH" in
  1) RES=1920x1080 ;;
  2) RES=3840x2160 ;;
  3) read -rp "Enter WxH: " RES ;;
  *) RES=1920x1080 ;;
esac
read -rp "URL to open (default https://example.com): " URL
URL=${URL:-https://example.com}

W=${RES%x*}
H=${RES#*x}

# ── 5. write start_kiosk.sh (Wayland + fallback) ───────────
sudo -u gui tee /home/gui/start_kiosk.sh >/dev/null <<EOF
#!/usr/bin/env bash
export XDG_RUNTIME_DIR="/run/user/\$(id -u)"
export QT_QPA_PLATFORM=wayland            # for maliit

LOG=/home/gui/kiosk.log
echo "===== kiosk start \$(date) =====" > "\$LOG"

# --- launch Weston -------------------------------------------------
if [ -e /dev/dri/card0 ]
then
    BACKEND="--backend=drm-backend.so --width=$W --height=$H --idle-time=0"
else
    BACKEND="--backend=fbdev-backend.so --width=$W --height=$H --idle-time=0"
fi

dbus-run-session -- weston \$BACKEND >>"\$LOG" 2>&1 &

# wait up to 5s for wayland-0 socket
for i in {1..5}
do
    [ -S "\$XDG_RUNTIME_DIR/wayland-0" ] && break
    sleep 1
done

if [ -S "\$XDG_RUNTIME_DIR/wayland-0" ]
then
    echo "Wayland ready – launching maliit & Chromium" >>"\$LOG"
    maliit-server >>"\$LOG" 2>&1 &
    exec chromium \
        --ozone-platform=wayland \
        --kiosk \
        --no-first-run \
        --disable-infobars \
        --disable-session-crashed-bubble \
        --enable-touch-events \
        "$URL"
fi

# --- fallback X11 --------------------------------------------------
echo "Wayland failed – switching to X11 path" >>"\$LOG"
unset QT_QPA_PLATFORM
startx /home/gui/.xsession
EOF

chmod +x /home/gui/start_kiosk.sh
chown gui:gui /home/gui/start_kiosk.sh

# ── 6. .bash_profile (runs script on tty1) ─────────────────
sudo -u gui tee /home/gui/.bash_profile >/dev/null <<'EOF'
[[ $(tty) = /dev/tty1 ]] && /home/gui/start_kiosk.sh
EOF
chmod 644 /home/gui/.bash_profile

# ── 7. .xsession for fallback X11 ──────────────────────────
sudo -u gui tee /home/gui/.xsession >/dev/null <<EOF
#!/bin/sh
xset s off -dpms &
unclutter -idle 300 &
matchbox-window-manager &
(sleep 5 && /home/gui/onboard_watcher.sh) &
exec chromium \
  --kiosk \
  --no-first-run \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --enable-touch-events \
  "$URL"
EOF
chmod +x /home/gui/.xsession
chown gui:gui /home/gui/.xsession

# ── 8. class‑based Onboard watcher (X11 only) ──────────────
sudo -u gui tee /home/gui/onboard_watcher.sh >/dev/null <<'EOF'
#!/bin/bash
LOG=/home/gui/onboard-focus.log
echo "watcher start $(date)" > "$LOG"
while true
do
    wid=$(xdotool getwindowfocus)
    class=$(xprop -id "$wid" WM_CLASS 2>/dev/null | awk -F\" '{print $4}')
    echo "$(date +%T) class:$class" >> "$LOG"
    if echo "$class" | grep -qiE 'chromium|chrome'
    then
        pgrep -x onboard >/dev/null || onboard &
    else
        pkill onboard
    fi
    sleep 1
done
EOF
chmod +x /home/gui/onboard_watcher.sh
chown gui:gui /home/gui/onboard_watcher.sh

# ── 9. restart getty so settings take effect ───────────────
systemctl daemon-reload
systemctl restart getty@tty1

echo
echo "===============  INSTALL COMPLETE  ==============="
echo " URL        : $URL"
echo " Resolution : $RES"
echo
echo "Boot flow:"
echo "  • Tries Weston ($W×$H) – if it works you get Wayland + maliit keyboard."
echo "  • If Weston fails in 5 s, falls back to X11 (Matchbox + Onboard watcher)."
echo
echo "Logs:"
echo "  Wayland/X path  : /home/gui/kiosk.log"
echo "  X11 keyboard log: /home/gui/onboard-focus.log (only in fallback)"
echo "Reboot or switch to TTY 1 to test."
echo "==================================================="
