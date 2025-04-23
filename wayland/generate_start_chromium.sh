#!/usr/bin/env bash
# generate_start_chromium.sh
# Writes /home/gui/start_chromium.sh and points Weston shell to it

set -euo pipefail

URL=${1:-"https://example.com"}
OUT="/home/gui/start_chromium.sh"
INI="/home/gui/.config/weston.ini"

log() {
  echo -e "[chromium-setup] $*"
}

log "Creating $OUT"
mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<EOF
#!/usr/bin/env bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export QT_QPA_PLATFORM=wayland
export WESTON_DEBUG=1

LOG=~/kiosk-chromium.log
: > \$LOG
chmod 664 \$LOG

exec chromium --ozone-platform=wayland --enable-wayland-ime --kiosk \
     --no-first-run --disable-infobars --disable-session-crashed-bubble \
     --enable-touch-events "$URL" >> \$LOG 2>&1
EOF

chown gui:gui "$OUT"
chmod +x "$OUT"
log "Chromium launch script created at $OUT"

log "Ensuring Weston shell points to Chromium"
mkdir -p "$(dirname "$INI")"
cat > "$INI" <<EOF
[core]
shell=$OUT
EOF

chown gui:gui "$INI"
chmod 644 "$INI"
log "Weston config updated to launch Chromium"
