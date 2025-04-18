#!/usr/bin/env bash
##############################################################################
#  Wayland‑only Kiosk Installer – Daniel Van Den Bosch                       #
#  * Creates user gui  * Sets tty1 autologin  * Boots Weston + Chromium      #
#  * Auto‑popping Weston on‑screen keyboard                                  #
#  * Fails (non‑zero exit) if Weston socket not ready in 6 seconds           #
##############################################################################
set -euo pipefail
INSTALL_LOG=/var/log/kiosk_install.log
exec > >(tee -a "$INSTALL_LOG") 2>&1
echo "===== INSTALL START  $(date) ====="

die(){ echo "❌  $*"; exit 1; }

pkg(){
  if dpkg -s "$1" &>/dev/null; then
    echo "• $1 already present"
  else
    echo "• Installing $1"
    apt-get install -y "$1" || die "Package $1 failed to install"
  fi
}

as_gui(){ sudo -u gui bash -c "$*"; }

##############################################################################
## 0. root check
##############################################################################
[ "$(id -u)" -eq 0 ] || die "Run this installer as root (sudo)."

##############################################################################
## 1. user gui
##############################################################################
if ! id -u gui &>/dev/null; then
  echo "• Creating user gui"
  useradd -m -s /bin/bash gui
  echo "gui:gui" | chpasswd
fi
usermod -aG dialout gui

##############################################################################
## 2. autologin on tty1
##############################################################################
echo "• Enabling autologin on tty1"
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I $TERM
EOF

##############################################################################
## 3. packages
##############################################################################
echo "• Updating apt repositories"
apt-get update -y
for p in weston chromium maliit-keyboard; do pkg "$p"; done
command -v chromium >/dev/null || die "Chromium binary missing after install"

##############################################################################
## 4. runtime configuration (resolution, URL)
##############################################################################
read -rp "Resolution (e.g. 1920x1080) [default 1920x1080]: " RES
RES=${RES:-1920x1080}
[[ $RES =~ ^[0-9]+x[0-9]+$ ]] || die "Resolution format must be WxH"
W=${RES%x*}; H=${RES#*x}

read -rp "URL to open [default https://example.com]: " URL
URL=${URL:-https://example.com}

echo "• Using resolution $RES  |  URL $URL"

##############################################################################
## 5. Weston configuration – enable built‑in keyboard
##############################################################################
echo "• Writing ~/.config/weston.ini"
as_gui "mkdir -p ~/.config"
# Ensure the weston-keyboard helper path is correct
KEYBOARD_BIN=$(dpkg -L weston | grep -m1 weston-keyboard) || \
  die "weston-keyboard helper not found in package"
as_gui "cat > ~/.config/weston.ini <<INI
[core]
idle-time=0

[keyboard]
command=$KEYBOARD_BIN
INI"

##############################################################################
## 6. start_kiosk.sh  (Wayland only, fail‑fast)
##############################################################################
echo "• Writing start_kiosk.sh"
as_gui "cat > ~/start_kiosk.sh <<'SK'
#!/usr/bin/env bash
export XDG_RUNTIME_DIR=/run/user/\$(id -u)
export QT_QPA_PLATFORM=wayland
LOG=\$HOME/kiosk-weston.log
echo '[kiosk] boot ' \$(date) > \$LOG

# Choose backend
if [ -e /dev/dri/card0 ]; then
  BACKEND_ARGS='--backend=drm-backend.so --width=$W --height=$H --idle-time=0'
else
  BACKEND_ARGS='--backend=fbdev-backend.so --width=$W --height=$H --idle-time=0'
fi
echo '[kiosk] backend args: ' \$BACKEND_ARGS >> \$LOG

dbus-run-session -- weston \$BACKEND_ARGS >>\$LOG 2>&1 &
PID=\$!

# Wait up to 6s for the Wayland socket
for i in {1..6}; do
  [ -S \$XDG_RUNTIME_DIR/wayland-0 ] && READY=1 && break
  sleep 1
done

if [ \"\$READY\" != 1 ]; then
  echo '[kiosk] Weston socket not ready – exiting.' >>\$LOG
  kill \$PID 2>/dev/null || true
  exit 1
fi

echo '[kiosk] Weston ready – launching keyboard + Chromium' >>\$LOG
maliit-server >>\$LOG 2>&1 &
exec chromium \
  --ozone-platform=wayland \
  --enable-wayland-ime \
  --kiosk \
  --no-first-run \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --enable-touch-events \
  \"$URL\"
SK
chmod +x ~/start_kiosk.sh"

##############################################################################
## 7. .bash_profile to invoke kiosk launcher
##############################################################################
echo "• Writing .bash_profile"
as_gui "cat > ~/.bash_profile <<'BP'
# Only run on tty1 and when no Wayland session yet
[[ -z \$WAYLAND_DISPLAY && \$(tty) = /dev/tty1 ]] && ~/start_kiosk.sh
BP
chmod 644 ~/.bash_profile"

##############################################################################
## 8. restart getty so autologin picks up
##############################################################################
systemctl daemon-reload
systemctl restart getty@tty1

echo
echo "========== INSTALL COMPLETE =========="
echo "  Resolution : $RES"
echo "  URL        : $URL"
echo
echo "• Reboot or switch to tty1."
echo "  - Weston should appear briefly, then Chromium."
echo "  - Tap any text field: Weston keyboard pops (via text‑input‑v3)."
echo "• Troubleshooting:"
echo "    sudo tail -f /home/gui/kiosk-weston.log"
echo "    sudo tail -f $INSTALL_LOG"
echo "======================================"
echo "===== INSTALL END    $(date) ====="
