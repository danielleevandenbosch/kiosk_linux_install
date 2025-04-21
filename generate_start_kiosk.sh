#!/usr/bin/env bash
# generate_start_kiosk.sh
# Generates /home/gui/start_kiosk.sh with injected resolution and Weston path

set -euo pipefail

W=${1:-1920}
H=${2:-1080}
URL=${3:-"https://example.com"}
WESTON_LAUNCH_BIN=${4:-"/usr/bin/weston-launch"}

cat > /home/gui/start_kiosk.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail

export XDG_RUNTIME_DIR=/run/user/\$(id -u)
export QT_QPA_PLATFORM=wayland
export WESTON_DEBUG=1
LOG=\$HOME/kiosk-weston.log
: > \$LOG
chmod 664 \$LOG

# Removed invalid --width and --height options
BACKEND='--backend=drm-backend.so'
ARGS="\$BACKEND --idle-time=0 --debug"
echo "[kiosk] $WESTON_LAUNCH_BIN -- \$ARGS" >> \$LOG

$WESTON_LAUNCH_BIN -- \$ARGS >> \$LOG 2>&1 &
PID=\$!

READY=0
for i in {1..6}; do
  [ -S \$XDG_RUNTIME_DIR/wayland-0 ] && READY=1 && break
  sleep 1
done

if [ "\$READY" != 1 ]; then
  chown \$(id -u):\$(id -g) \$LOG
  echo "-------------------------------------------------" >/dev/tty1
  echo "Weston FAILED – last 60 log lines:" >/dev/tty1
  echo "-------------------------------------------------" >/dev/tty1
  tail -n 60 \$LOG | tee /dev/tty1
  kill \$PID 2>/dev/null || true
  exit 1
fi

echo "[kiosk] Weston ready" >> \$LOG
maliit-server >> \$LOG 2>&1 &
exec chromium --ozone-platform=wayland --enable-wayland-ime --kiosk \
     --no-first-run --disable-infobars --disable-session-crashed-bubble \
     --enable-touch-events "$URL"
EOF

chown gui:gui /home/gui/start_kiosk.sh
chmod +x /home/gui/start_kiosk.sh
