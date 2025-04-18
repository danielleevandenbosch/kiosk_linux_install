#!/usr/bin/env bash
# Daniel Van Den Bosch – Wayland kiosk auto‑ricer

set -e

# ───────────────────────── 0.  root check
if [ "$(id -u)" -ne 0 ]
then
    echo "Run as root (sudo)."
    exit 1
fi

# ───────────────────────── 1.  gui user
if ! id -u gui >/dev/null 2>&1
then
    useradd -m -s /bin/bash gui
    echo "gui:gui" | chpasswd
fi
usermod -aG dialout gui

# ───────────────────────── 2.  autologin on tty1
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I \$TERM
EOF

# ───────────────────────── 3.  packages
echo "Updating apt lists…"
apt-get update -y

PACKAGES=(
  weston
  weston-launch
  weston-xwayland
  chromium
  maliit-keyboard
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
    if ! dpkg -s "$p" &>/dev/null
    then
        echo "Installing $p …"
        apt-get install -y "$p" || echo "⚠️  $p not available—continuing."
    fi
done

# ───────────────────────── 4.  chromium binary path
if command -v chromium >/dev/null
then
    CHROME=chromium
else
    echo "❌ Chromium package not present; abort."
    exit 1
fi

# ───────────────────────── 5.  resolution + URL
echo "Select HDMI‑1 resolution:"
echo "1) 1080p   2) 4K   3) custom"
read -rp "Choice [1‑3]: " CH
case "$CH" in
  1)  RES=1920x1080 ;;
  2)  RES=3840x2160 ;;
  3)  read -rp "Custom WxH: " RES ;;
  *)  RES=1920x1080 ;;
esac
read -rp "URL (default https://example.com): " URL
URL=${URL:-https://example.com}

RES_WIDTH=${RES%x*}
RES_HEIGHT=${RES#*x}

# ───────────────────────── 6.  gui start script
sudo -u gui tee /home/gui/start_kiosk_wayland.sh >/dev/null <<EOF
#!/usr/bin/env bash
export XDG_RUNTIME_DIR="/run/user/\$(id -u)"

# ── launch Weston compositor (find correct launcher)
if command -v weston-launch >/dev/null
then
    weston-launch -- --width=${RES_WIDTH} --height=${RES_HEIGHT} --idle-time=0 &
elif [ -x /usr/libexec/weston-launch ]
then
    /usr/libexec/weston-launch -- --width=${RES_WIDTH} --height=${RES_HEIGHT} --idle-time=0 &
else
    dbus-run-session -- weston --width=${RES_WIDTH} --height=${RES_HEIGHT} --idle-time=0 &
fi

sleep 2   # give compositor a moment

# ── start on‑screen keyboard (Wayland IM)
maliit-server &

# ── run Chromium in foreground (kiosk)
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

# ───────────────────────── 7.  .bash_profile to autostart script
sudo -u gui tee /home/gui/.bash_profile >/dev/null <<'EOF'
# auto‑start Wayland kiosk when this is tty1
if [[ -z $WAYLAND_DISPLAY && $(tty) = /dev/tty1 ]]
then
    /home/gui/start_kiosk_wayland.sh
fi
EOF
chmod 644 /home/gui/.bash_profile

# ───────────────────────── 8.  reload getty
systemctl daemon-reload
systemctl restart getty@tty1

echo "==================== INSTALL COMPLETE ===================="
echo "User auto‑login : gui (TTY1)"
echo "Resolution      : $RES"
echo "URL             : $URL"
echo "Compositor      : Weston + maliit‑keyboard"
echo
echo "Reboot or switch to TTY1; Weston will launch."
echo "Tap any input field in Chromium, and the on‑screen keyboard"
echo "should appear automatically via Wayland text‑input‑v3."
echo "=========================================================="
