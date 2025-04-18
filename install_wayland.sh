#!/usr/bin/env bash
# Wayland kiosk auto‑ricer   –   Debian 12 (Bookworm) friendly

set -e
[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }

# ── create gui user ──────────────────────────────────────────
id -u gui &>/dev/null || { useradd -m -s /bin/bash gui; echo "gui:gui" | chpasswd; }
usermod -aG dialout gui

# ── autologin on tty1 ───────────────────────────────────────
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I $TERM
EOF

# ── install packages (skip missing) ─────────────────────────
apt-get update -y
PKGS=( weston chromium maliit-keyboard network-manager openssh-client openssh-server zsh vim neofetch htop )
for p in "${PKGS[@]}"; do
    dpkg -s "$p" &>/dev/null || apt-get install -y "$p" || echo "⚠️  $p not available—continuing."
done

command -v chromium >/dev/null || { echo "Chromium not installed. Abort."; exit 1; }
CHROME=chromium

# ── prompt resolution + URL ─────────────────────────────────
echo "1)1080p  2)4K  3)custom" ; read -rp "Choose res [1‑3]: " C
case $C in
  1) RES=1920x1080 ;;  2) RES=3840x2160 ;;
  3) read -rp "Custom WxH: " RES ;;  *) RES=1920x1080 ;;
esac
read -rp "URL (default https://example.com): " URL
URL=${URL:-https://example.com}
W=${RES%x*} ; H=${RES#*x}

# ── gui start script ────────────────────────────────────────
sudo -u gui tee /home/gui/start_kiosk_wayland.sh >/dev/null <<EOF
#!/usr/bin/env bash
export XDG_RUNTIME_DIR="/run/user/\$(id -u)"

# Start Weston in whichever way exists
if command -v weston-launch >/dev/null; then
    weston-launch -- --width=$W --height=$H --idle-time=0 &
elif [ -x /usr/libexec/weston-launch ]; then
    /usr/libexec/weston-launch -- --width=$W --height=$H --idle-time=0 &
else
    dbus-run-session -- weston --width=$W --height=$H --idle-time=0 &
fi

sleep 2
maliit-server &

exec $CHROME \
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

# ── .bash_profile ───────────────────────────────────────────
sudo -u gui tee /home/gui/.bash_profile >/dev/null <<'EOF'
[[ -z $WAYLAND_DISPLAY && $(tty) = /dev/tty1 ]] && /home/gui/start_kiosk_wayland.sh
EOF
chmod 644 /home/gui/.bash_profile

# ── restart autologin getty ─────────────────────────────────
systemctl daemon-reload
systemctl restart getty@tty1

echo "-------------------  INSTALL DONE  -------------------"
echo "User auto‑login : gui"
echo "Resolution      : $RES"
echo "URL             : $URL"
echo "Weston + maliit keyboard will launch on TTY1."
echo "Tap any input field in Chromium to see the on‑screen keyboard."
