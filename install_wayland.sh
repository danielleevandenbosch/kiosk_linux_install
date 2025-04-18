#!/usr/bin/env bash
# Daniel Van Den Bosch – Wayland kiosk auto‑ricer (with cleanup)

set -e

# ───────────────────────── 0.  root check
[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)."; exit 1; }

GUI_HOME=/home/gui

# ───────────────────────── 1.  ensure gui user
if ! id -u gui >/dev/null 2>&1
then
    useradd -m -s /bin/bash gui
    echo "gui:gui" | chpasswd
fi
usermod -aG dialout gui

# ───────────────────────── 2.  CLEANUP old X files & old scripts
echo "Cleaning up old X11 configs…"
rm -f \
    "$GUI_HOME/.bash_profile" \
    "$GUI_HOME/.xinitrc" \
    "$GUI_HOME/.xsession" \
    "$GUI_HOME/start_kiosk_wayland.sh" \
    "$GUI_HOME/launch_onboard_on_focus.sh"

# ───────────────────────── 3.  autologin on tty1 (systemd override)
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I \$TERM
EOF

# ───────────────────────── 4.  install packages (Wayland stack)
echo "Updating apt lists…"
apt-get update -y

PKGS=(
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
for p in "${PKGS[@]}"; do
    dpkg -s "$p" &>/dev/null || \
      apt-get install -y "$p" || \
      echo "⚠️  Package '$p' not available—continuing."
done

# ───────────────────────── 5.  chromium path
command -v chromium >/dev/null || { echo "Chromium missing, abort."; exit 1; }
CHROME=chromium

# ───────────────────────── 6.  resolution & URL prompt
echo "Resolution  1)1080p  2)4K  3)custom"
read -rp "Choose [1‑3]: " CH
case $CH in
  1) RES=1920x1080 ;;
  2) RES=3840x2160 ;;
  3) read -rp "Custom WxH: " RES ;;
  *) RES=1920x1080 ;;
esac
read -rp "URL (default https://example.com): " URL
URL=${URL:-https://example.com}
RES_W=${RES%x*}
RES_H=${RES#*x}

# ───────────────────────── 7.  start_kiosk_wayland.sh
sudo -u gui tee "$GUI_HOME/start_kiosk_wayland.sh" >/dev/null <<EOF
#!/usr/bin/env bash
export XDG_RUNTIME_DIR="/run/user/\$(id -u)"

# --- start Weston (pick first launcher path that exists) ---
if command -v weston-launch >/dev/null; then
    weston-launch -- --width=${RES_W} --height=${RES_H} --idle-time=0 &
elif [ -x /usr/libexec/weston-launch ]; then
    /usr/libexec/weston-launch -- --width=${RES_W} --height=${RES_H} --idle-time=0 &
else
    dbus-run-session -- weston --width=${RES_W} --height=${RES_H} --idle-time=0 &
fi

sleep 2   # compositor warm‑up
maliit-server &

exec ${CHROME} \
    --ozone-platform=wayland \
    --kiosk \
    --no-first-run \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --enable-touch-events \
    "${URL}"
EOF
chmod +x "$GUI_HOME/start_kiosk_wayland.sh"
chown gui:gui "$GUI_HOME/start_kiosk_wayland.sh"

# ───────────────────────── 8.  minimal .bash_profile (Wayland only)
sudo -u gui tee "$GUI_HOME/.bash_profile" >/dev/null <<'EOF'
# Auto‑start Wayland kiosk on tty1
if [[ -z $WAYLAND_DISPLAY && $(tty) = /dev/tty1 ]]; then
    /home/gui/start_kiosk_wayland.sh
fi
EOF
chmod 644 "$GUI_HOME/.bash_profile"

# ───────────────────────── 9.  reload getty & finish
systemctl daemon-reload
systemctl restart getty@tty1

echo "==================== INSTALL COMPLETE ===================="
echo "User auto‑login : gui"
echo "Resolution      : $RES"
echo "URL             : $URL"
echo "Compositor      : Weston (Wayland) + maliit‑keyboard"
echo "Old X11 configs cleaned."
echo "Reboot or switch to TTY1 – keyboard should appear on input focus."
echo "=========================================================="
