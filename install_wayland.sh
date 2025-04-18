#!/usr/bin/env bash
# Daniel Van Den Bosch — Wayland kiosk installer

set -e

# ── 0. root check
[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }

# ── 1. gui user
id -u gui &>/dev/null || {
    useradd -m -s /bin/bash gui
    echo "gui:gui" | chpasswd
}
usermod -aG dialout gui

# ── 2. autologin on tty1
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I \$TERM
EOF

# ── 3. packages (Wayland stack)
echo "apt update…"
apt-get update -y

PKGS=(
  weston
  weston-launch
  chromium
  unclutter
  maliit-keyboard
  network-manager
  openssh-client
  openssh-server
  zsh
  vim
  neofetch
  htop
)
for p in "${PKGS[@]}"; do
  dpkg -s "$p" &>/dev/null || \
    apt-get install -y "$p" || echo "⚠️  $p not available—continuing"
done

# ── 4. chromium binary
command -v chromium >/dev/null && CHROME=chromium
[ -z "$CHROME" ] && { echo "chromium not installed, abort"; exit 1; }

# ── 5. resolution + URL
echo "1)1080p  2)4K  3)custom"
read -rp "Choose [1‑3]: " C
case $C in
  1) RES=1920x1080 ;;
  2) RES=3840x2160 ;;
  3) read -rp "Enter WxH: " RES ;;
  *) RES=1920x1080 ;;
esac
read -rp "URL (default https://example.com): " URL
URL=${URL:-https://example.com}

# ── 6. start script for gui
sudo -u gui tee /home/gui/start_kiosk_wayland.sh >/dev/null <<EOF
#!/usr/bin/env bash
export XDG_RUNTIME_DIR="/run/user/\$(id -u)"

# DRM backend (real screens) — set desired mode
weston-launch \
  -- --width=${RES%x*} --height=${RES#*x} --idle-time=0 &

# give Weston a moment
sleep 2

# launch maliit once
maliit-server &

# hide pointer after 5 min
unclutter -idle 300 &

# run chromium in foreground (kiosk)
exec ${CHROME} \
  --ozone-platform=wayland \
  --kiosk \
  --no-first-run \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --enable-touch-events \
  "${URL}"
EOF
chmod +x /home/gui/start_kiosk_wayland.sh
chown gui:gui /home/gui/start_kiosk_wayland.sh

# ── 7. .bash_profile to trigger script
sudo -u gui tee /home/gui/.bash_profile >/dev/null <<'EOF'
if [[ -z $WAYLAND_DISPLAY && $(tty) = /dev/tty1 ]]; then
    /home/gui/start_kiosk_wayland.sh
fi
EOF
chmod 644 /home/gui/.bash_profile

# ── 8. reload getty
systemctl daemon-reload
systemctl restart getty@tty1

echo "========================================="
echo "Wayland kiosk installed!"
echo "User auto‑login : gui"
echo "Resolution      : $RES"
echo "URL             : $URL"
echo "Backend         : Weston + maliit‑keyboard"
echo "Run logon and you should see the on‑screen keyboard pop automatically."
echo "========================================="
