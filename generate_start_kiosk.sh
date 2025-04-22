#!/usr/bin/env bash
# generate_start_kiosk.sh
# -----------------------------------------------------------------------------
# This script generates the /home/gui/start_kiosk.sh script used to launch Weston.
#
# Weston will be launched as the display server in kiosk mode using the DRM backend.
# It will log all output to ~/kiosk-weston.log, and verify that Wayland is up
# by checking the existence of the wayland-0 socket. If Weston fails to initialize,
# the script outputs the last 60 lines of the log to /dev/tty1 for troubleshooting.
#
# Weston itself will then launch Chromium as its shell, via weston.ini.
# -----------------------------------------------------------------------------

set -euo pipefail

W=${1:-1920}                         # Optional: not directly used anymore, kept for compatibility
H=${2:-1080}
URL=${3:-"https://example.com"}     # Optional: not directly used unless used in chromium shell
WESTON_LAUNCH_BIN=${4:-"/usr/bin/weston"}  # Legacy support, but not directly used

cat > /home/gui/start_kiosk.sh <<'EOF'
#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# /home/gui/start_kiosk.sh
#
# This script is executed from .bash_profile when 'gui' logs into tty1.
# It starts Weston (Wayland compositor) with the DRM backend, disables idle timeout,
# and writes logs to ~/kiosk-weston.log. If Weston fails to start or bind to
# the Wayland display socket, the script dumps diagnostics to tty1.
#
# Chromium is not launched here. Weston is configured to launch it via
# ~/.config/weston.ini using the shell=/home/gui/start_chromium.sh setting.
# -----------------------------------------------------------------------------

set -euo pipefail

# Set up required environment variables for Wayland session
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export QT_QPA_PLATFORM=wayland         # Tells Qt apps (if any) to use Wayland
export WESTON_DEBUG=1                  # Enables verbose Weston logs

LOG=$HOME/kiosk-weston.log             # Location for the Weston log
: > "$LOG"                             # Clear/create the log file
chmod 664 "$LOG"                       # Readable by user and group

# Detect Weston binary: prefer weston-launch if present, fallback to weston
if command -v weston-launch &>/dev/null; then
  WESTON_BIN=$(command -v weston-launch)
else
  WESTON_BIN=$(command -v weston)
fi

# Construct arguments for Weston
# --backend=drm-backend.so: Use direct rendering (no X)
# --idle-time=0: Prevent blanking or power-saving screen timeout
ARGS="--backend=drm-backend.so --idle-time=0 --debug"

# Log the Weston launch command
echo "[kiosk] Launching: $WESTON_BIN $ARGS" >> "$LOG"

# Launch Weston in the background and capture the process ID
"$WESTON_BIN" $ARGS >> "$LOG" 2>&1 &
PID=$!

# Wait for Weston to create the Wayland display socket
READY=0
for i in {1..6}; do
  [ -S "$XDG_RUNTIME_DIR/wayland-0" ] && READY=1 && break
  sleep 1
done

# If Weston didn't bind to the Wayland display, dump logs and exit with error
if [ "$READY" != 1 ]; then
  chown $(id -u):$(id -g) "$LOG"
  echo "-------------------------------------------------" > /dev/tty1
  echo "❌ Weston FAILED – last 60 log lines:" > /dev/tty1
  echo "-------------------------------------------------" > /dev/tty1
  tail -n 60 "$LOG" | tee /dev/tty1
  kill "$PID" 2>/dev/null || true
  exit 1
fi

# Success
echo "[kiosk] ✅ Weston ready" >> "$LOG"
EOF

# Set appropriate ownership and permissions for the generated script
chown gui:gui /home/gui/start_kiosk.sh
chmod +x /home/gui/start_kiosk.sh
