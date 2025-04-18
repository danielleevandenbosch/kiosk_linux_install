#!/usr/bin/env bash
##############################################################################
#  Wayland‑ONLY Kiosk Installer (verbose / fail‑fast)                        #
#  Author: Daniel Van Den Bosch                                              #
##############################################################################
set -euo pipefail
INSTALL_LOG=/var/log/kiosk_install.log
exec > >(tee -a "$INSTALL_LOG") 2>&1
echo "===== INSTALL START  $(date) ====="

die(){ echo "❌  $*"; exit 1; }

pkg(){
    if dpkg -s "$1" &>/dev/null; then
        echo "• $1 already installed"
    else
        echo "• Installing $1"
        apt-get install -y "$1" || die "Package $1 failed to install"
    fi
}

as_gui(){ sudo -u gui bash -c "$*"; }

##############################################################################
# 0. Root check
##############################################################################
[ "$(id -u)" -eq 0 ] || die "Run this installer as root (sudo)."

##############################################################################
# 1. Create/adjust gui user
##############################################################################
if ! id -u gui &>/dev/null; then
    echo "• Creating user gui"
    useradd -m -s /bin/bash gui
    echo "gui:gui" | chpasswd
fi
# ── give gui access to /dev/dri/card0 (video group) and serial (dialout)
usermod -aG dialout,video gui

##############################################################################
# 2. Autologin on tty1
##############################################################################
echo "• Setting autologin on tty1"
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I $TERM
EOF

##############################################################################
# 3. Packages (Wayland only)
##############################################################################
echo "• Updating apt cache"; apt-get update -y
for p in weston chromium maliit-keyboard; do pkg "$p"; done
command -v chromium >/dev/null || die "Chromium not present after install."

##############################################################################
# 4. Runtime parameters
##############################################################################
read -rp "Resolution (WxH) [1920x1080]: " RES
RES=${RES:-1920x1080}
[[ $RES =~ ^[0-9]+x[0-9]+$ ]] || die "Resolution must be WxH"
W=${RES%x*}; H=${RES#*x}

read -rp "URL to open [https://example.com]: " URL
URL=${URL:-https://example.com}

echo "• Using ${W}x${H}  URL=$URL"

##############################################################################
# 5. weston.ini with on‑screen keyboard
##############################################################################
KEYBOARD_BIN=$(dpkg -L weston | grep -m1 weston-keyboard) || die "weston-keyboard helper not found"
echo "• Writing ~/.config/weston.ini (keyboard helper: $KEYBOARD_BIN)"
as_gui "mkdir -p ~/.config && cat > ~/.config/weston.ini <<INI
[core]
idle-time=0

[keyboard]
command=$KEYBOARD_BIN
INI"

##############################################################################
# 6. start_kiosk.sh  (verbose; fail‑fast)
##############################################################################
echo "• Writing start_kiosk.sh"
as_gui "cat > ~/start_kiosk.sh <<'SK'
#!/usr/bin/env bash
export XDG_RUNTIME_DIR=/run/user/\$(id -u)
export QT_QPA_PLATFORM=wayland
export WESTON_DEBUG=1

LOG=\$HOME/kiosk-weston.log
echo -e \"\\n=== kiosk boot \$(date) ===\" > \$LOG

# choose backend: drm if /dev/dri/card0 exists, otherwise fbdev
if [ -e /dev/dri/card0 ]; then
    BACKEND_ARGS='--backend=drm-backend.so'
else
    BACKEND_ARGS='--backend=fbdev-backend.so'
fi
BACKEND_ARGS=\"\$BACKEND_ARGS --width=$W --height=$H --idle-time=0 --debug\"

echo \"[kiosk] weston \$BACKEND_ARGS\" >> \$LOG
dbus-run-session -- weston \$BACKEND_ARGS >> \$LOG 2>&1 &
PID=\$!

# wait up to 6 s for wayland socket
for i in {1..6}
do
    [ -S \$XDG_RUNTIME_DIR/wayland-0 ] && READY=1 && break
    sleep 1
done

if [ \"\$READY\" != 1 ]; then
    echo \"[kiosk] Weston failed; dumping last 60 lines\" >> \$LOG
    echo \"---------------------------------------------------------\" >/dev/tty1
    echo \" Weston FAILED – see below (also \$LOG)\" >/dev/tty1
    echo \"---------------------------------------------------------\" >/dev/tty1
    tail -n 60 \$LOG | tee /dev/tty1
    kill \$PID 2>/dev/null || true
    exit 1
fi

echo \"[kiosk] Weston ready – launching maliit & Chromium\" >> \$LOG
maliit-server >> \$LOG 2>&1 &
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
# 7. .bash_profile auto‑launch
##############################################################################
echo "• Writing .bash_profile"
as_gui "cat > ~/.bash_profile <<'BP'
# Start kiosk only on tty1, no nested sessions
[[ -z \$WAYLAND_DISPLAY && \$(tty) = /dev/tty1 ]] && ~/start_kiosk.sh
BP"
chmod 644 /home/gui/.bash_profile

##############################################################################
# 8. Restart getty to apply autologin
##############################################################################
systemctl daemon-reload
systemctl restart getty@tty1

echo
echo "========== INSTALL COMPLETE =========="
echo " Resolution : $RES"
echo " URL        : $URL"
echo
echo " • Reboot now (or switch to tty1)."
echo " • Weston starts → Chromium loads."
echo " • Tap any input field → Weston on‑screen keyboard pops."
echo
echo " Failure? The last 60 Weston log lines will show on tty1."
echo " Full log  : /home/gui/kiosk-weston.log"
echo " Install   : $INSTALL_LOG"
echo "======================================"
