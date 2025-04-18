#!/usr/bin/env bash
# install_wayland.sh
# Master Wayland-only kiosk ricer, calls dependency script first

set -euo pipefail
INSTALL_LOG=/var/log/kiosk_install.log
exec > >(tee -a "$INSTALL_LOG") 2>&1

log() { echo -e "[installer] $*"; }
die() { echo "❌  $*"; exit 1; }
pkg() { dpkg -s "$1" &>/dev/null || apt-get install -y "$1" || die "pkg $1"; }
as_gui() { sudo -u gui bash -c "$*"; }

[ "$(id -u)" -eq 0 ] || die "Run as root."

log "Calling dependency installer..."
bash ./install_wayland_dependancies.sh || die "Dependency script failed."

# ── 1. user gui ────────────────────────────────────────────────────────────
id -u gui &>/dev/null || { useradd -m -s /bin/bash gui; echo gui:gui | chpasswd; }
usermod -aG dialout,video gui

# ── 2. autologin tty1 ──────────────────────────────────────────────────────
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I $TERM
EOF

# ── 3. weston-launch detection ─────────────────────────────────────────────
WESTON_LAUNCH_BIN=""
for path in \
    "$(command -v weston-launch 2>/dev/null)" \
    /usr/bin/weston-launch \
    /usr/libexec/weston-launch
  do
    if [ -x "$path" ]; then
      WESTON_LAUNCH_BIN="$path"
      break
    fi
done

if [ -z "$WESTON_LAUNCH_BIN" ]; then
  die "weston-launch not found. Install weston-launch or check your Weston install."
fi
chmod u+s "$WESTON_LAUNCH_BIN"
echo "• Using weston-launch: $WESTON_LAUNCH_BIN"

# ── 4. prompt ─────────────────────────────────────────────────────────────
read -rp "Resolution (WxH) [1920x1080]: " RES
RES=${RES:-1920x1080}
[[ $RES =~ ^[0-9]+x[0-9]+$ ]] || die "Bad resolution"
W=${RES%x*}; H=${RES#*x}
read -rp "URL to open [https://example.com]: " URL
URL=${URL:-https://example.com}
echo "• Using resolution ${W}x${H}, URL=$URL"

# ── 5. weston.ini ─────────────────────────────────────────────────────────
KEYBD=$(dpkg -L weston | grep -m1 weston-keyboard) || die "weston-keyboard not found"
as_gui "mkdir -p ~/.config && cat > ~/.config/weston.ini <<INI
[core]
idle-time=0
[keyboard]
command=$KEYBD
INI"

# ── 6. start_kiosk.sh ─────────────────────────────────────────────────────
as_gui "cat > ~/start_kiosk.sh <<SK
#!/usr/bin/env bash
export XDG_RUNTIME_DIR=/run/user/\$(id -u)
export QT_QPA_PLATFORM=wayland
export WESTON_DEBUG=1
LOG=\$HOME/kiosk-weston.log
rm -f \$LOG; touch \$LOG; chmod 664 \$LOG

echo \"[kiosk] boot \$(date)\" > \$LOG

BACKEND='--backend=drm-backend.so'
ARGS=\"\$BACKEND --width=$W --height=$H --idle-time=0 --debug\"
echo \"[kiosk] $WESTON_LAUNCH_BIN -- \$ARGS\" >>\$LOG

$WESTON_LAUNCH_BIN -- \$ARGS >>\$LOG 2>&1 &
PID=\$!

for i in {1..6}; do [ -S \$XDG_RUNTIME_DIR/wayland-0 ] && READY=1 && break; sleep 1; done

if [ \"\$READY\" != 1 ]; then
  chown \$(id -u):\$(id -g) \$LOG
  echo \"-------------------------------------------------\" >/dev/tty1
  echo \"Weston FAILED – last 60 log lines:\" >/dev/tty1
  echo \"-------------------------------------------------\" >/dev/tty1
  tail -n 60 \$LOG | tee /dev/tty1
  kill \$PID 2>/dev/null || true
  exit 1
fi

echo \"[kiosk] Weston ready\" >> \$LOG
maliit-server >> \$LOG 2>&1 &
exec chromium --ozone-platform=wayland --enable-wayland-ime --kiosk \
     --no-first-run --disable-infobars --disable-session-crashed-bubble \
     --enable-touch-events \"$URL\"
SK
chmod +x ~/start_kiosk.sh"

# ── 7. bash_profile ───────────────────────────────────────────────────────
as_gui "cat > ~/.bash_profile <<'BP'
[[ -z \$WAYLAND_DISPLAY && \$(tty) = /dev/tty1 ]] && ~/start_kiosk.sh
BP"
chmod 644 /home/gui/.bash_profile

# ── 8. finish ─────────────────────────────────────────────────────────────
systemctl daemon-reload
systemctl restart getty@tty1

echo
echo "===== INSTALL COMPLETE – REBOOT NOW ====="
echo "• Weston will launch via $WESTON_LAUNCH_BIN"
echo "• Logs will appear in /home/gui/kiosk-weston.log"
echo "• If it fails: last 60 lines dump to tty1"
