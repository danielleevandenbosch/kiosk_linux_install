#!/usr/bin/env bash
##############################################################################
#  Wayland‑ONLY Kiosk Installer – Daniel Van Den Bosch – verbose/fail‑fast   #
##############################################################################
set -euo pipefail
INSTALL_LOG=/var/log/kiosk_install.log
exec > >(tee -a "$INSTALL_LOG") 2>&1
echo "========== INSTALL START  $(date) =========="

die(){ echo -e "❌  $*\nSee $INSTALL_LOG"; exit 1; }

pkg(){ dpkg -s "$1" &>/dev/null || { echo "• Installing $1"; apt-get install -y "$1" || die "$1 failed"; } }

as_gui(){ sudo -u gui bash -c "$*"; }

# ── 0. root check ───────────────────────────────────────────────────────────
[ "$(id -u)" -eq 0 ] || die "Run as root."

# ── 1. user gui ─────────────────────────────────────────────────────────────
if ! id -u gui &>/dev/null; then
  echo "• Creating user gui"
  useradd -m -s /bin/bash gui
  echo "gui:gui" | chpasswd
fi
usermod -aG dialout gui

# ── 2. autologin tty1 ───────────────────────────────────────────────────────
echo "• Enabling autologin on tty1"
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I $TERM
EOF

# ── 3. packages ─────────────────────────────────────────────────────────────
echo "• Updating apt cache"; apt-get update -y
for p in weston chromium maliit-keyboard; do pkg "$p"; done
command -v chromium >/dev/null || die "Chromium not present after install."

# ── 4. runtime questions ───────────────────────────────────────────────────
read -rp "Resolution (WxH) [1920x1080]: " RES
RES=${RES:-1920x1080}
[[ $RES =~ ^[0-9]+x[0-9]+$ ]] || die "Bad resolution"
W=${RES%x*}; H=${RES#*x}

read -rp "URL to load [https://example.com]: " URL
URL=${URL:-https://example.com}
echo "• Config: ${W}x${H}  URL=$URL"

# ── 5. weston.ini with correct keyboard path ───────────────────────────────
KEYBD=$(dpkg -L weston | grep -m1 weston-keyboard) || die "weston-keyboard not found"
as_gui "mkdir -p ~/.config && cat >~/.config/weston.ini <<INI
[core]
idle-time=0
[keyboard]
command=$KEYBD
INI"

# ── 6. verbose Wayland launcher ────────────────────────────────────────────
as_gui "cat >~/start_kiosk.sh <<'SK'
#!/usr/bin/env bash
export XDG_RUNTIME_DIR=/run/user/\$(id -u)
export QT_QPA_PLATFORM=wayland
export WESTON_DEBUG=1
LOG=\$HOME/kiosk-weston.log
echo -e \"\\n=== kiosk boot \$(date) ===\" >\$LOG

# choose backend
if [ -e /dev/dri/card0 ]; then
  BACKEND_ARGS='--backend=drm-backend.so'
else
  BACKEND_ARGS='--backend=fbdev-backend.so'
fi
BACKEND_ARGS=\"\$BACKEND_ARGS --width=$W --height=$H --idle-time=0 --debug\"
echo \"[kiosk] weston \$BACKEND_ARGS\" >>\$LOG

dbus-run-session -- weston \$BACKEND_ARGS >>\$LOG 2>&1 &
PID=\$!

# wait up to 6 s for socket
for i in {1..6}; do
  [ -S \$XDG_RUNTIME_DIR/wayland-0 ] && READY=1 && break
  sleep 1
done

if [ \"\$READY\" != 1 ]; then
  echo \"[kiosk] Weston socket missing – dumping last 60 lines\" >>\$LOG
  echo \"------------------------------------------------------------\" >/dev/tty1
  echo \"Weston FAILED – see below (also \$LOG)\"                >/dev/tty1
  echo \"------------------------------------------------------------\" >/dev/tty1
  tail -n 60 \$LOG | tee /dev/tty1
  kill \$PID 2>/dev/null || true
  exit 1
fi

echo \"[kiosk] Weston ready – starting maliit & Chromium\" >>\$LOG
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

# ── 7. .bash_profile auto‑launch ───────────────────────────────────────────
as_gui "cat >~/.bash_profile <<'BP'
[[ -z \$WAYLAND_DISPLAY && \$(tty) = /dev/tty1 ]] && ~/start_kiosk.sh
BP"
chmod 644 /home/gui/.bash_profile

# ── 8. reload getty ────────────────────────────────────────────────────────
systemctl daemon-reload
systemctl restart getty@tty1

echo
echo "========== INSTALL COMPLETE =========="
echo "• Reboot → tty1 autologin → Weston tries to start."
echo "• On success: Chromium loads & Weston‑keyboard pops on focus."
echo "• On failure : last 60 log lines print on screen."
echo "  Full log    : /home/gui/kiosk-weston.log"
echo "  Install log : $INSTALL_LOG"
echo "======================================"
