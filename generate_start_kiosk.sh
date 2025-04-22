#!/usr/bin/env bash
# generate_start_kiosk.sh
# -----------------------------------------------------------------------------
# This script generates /home/gui/start_kiosk.sh used to launch Weston.
#
# Weston is started in DRM backend mode with logging, idle-time disabled, and
# startup validation based on the existence of the wayland socket.
# If Weston fails to initialize properly, the script will dump logs to tty1.
#
# Chromium itself is expected to be launched by Weston via weston.ini using
# the shell=/home/gui/start_chromium.sh directive.
# -----------------------------------------------------------------------------

set -euo pipefail

W=${1:-1920}                             # Unused, but retained for future use or validation
H=${2:-1080}
URL=${3:-"https://example.com"}         # Also unused here directly
WESTON_LAUNCH_BIN=${4:-"/usr/bin/weston"}  # Optional legacy input

log_file="/home/gui/start_kiosk.sh"
cat > "$log_file" <<'EOF'
#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# /home/gui/start_kiosk.sh
# Launches Weston from a TTY session in DRM backend mode
# -----------------------------------------------------------------------------

set -euo pipefail

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export QT_QPA_PLATFORM="wayland"
export WESTON_DEBUG=1

LOG="$HOME/kiosk-weston.log"
: > "$LOG"
chmod 664 "$LOG"

# Detect available Weston binary
if command -v weston-launch &>/dev/null; then
  WESTON_BIN="$(command -v weston-launch)"
else
  WESTON_BIN="$(command -v weston)"
fi

# Arguments for Weston session
ARGS="--backend=drm-backend.so --idle-time=0 --debug"

echo "[kiosk] Launching: $WESTON_BIN $ARGS" >> "$LOG"
"$WESTON_BIN" $ARGS >> "$LOG" 2>&1 &
PID=$!

# Wait for Weston to produce the wayland-0 socket
READY=0
for i in {1..10}; do
  if [ -S "$XDG_RUNTIME_DIR/wayland-0" ]; then
    READY=1
    break
  fi
  echo "[kiosk] Waiting for wayland-0 ($i/10)..." >> "$LOG"
  sleep 5
done

if [ "$READY" -ne 1 ]; then
  chown "$(id -u):$(id -g)" "$LOG"
  echo "-------------------------------------------------" > /dev/tty1
  echo "❌ Weston FAILED – last 60 log lines:" > /dev/tty1
  echo "-------------------------------------------------" > /dev/tty1
  tail -n 60 "$LOG" | tee /dev/tty1
  kill "$PID" 2>/dev/null || true
  exit 1
fi

echo "[kiosk] ✅ Weston ready at $(date)" >> "$LOG"
EOF

# Set ownership and permissions
chown gui:gui "$log_file"
chmod +x "$log_file"
