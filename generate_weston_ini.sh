#!/usr/bin/env bash
# generate_weston_ini.sh
# -----------------------------------------------------------------------------
# This script creates a Weston configuration file (~/.config/weston.ini)
# for the 'gui' user. Weston is a reference Wayland compositor, and this
# file is used to configure session-level behavior for the Wayland session.
#
# It ensures:
# - No screen blanking (idle-time=0)
# - Specific output resolution and monitor name (can be auto-detected)
# - On-screen keyboard is launched for kiosk/touch environments
# - Proper Weston shell is used (desktop-shell.so or kiosk-shell.so)
# -----------------------------------------------------------------------------

set -euo pipefail

log() {
  echo -e "[weston-ini] $*"
}

# Locate weston-keyboard binary
KEYBD=$(dpkg -L weston | grep -m1 weston-keyboard) || {
  echo "❌ weston-keyboard not found" >&2
  exit 1
}

# Defaults
RES_WIDTH="${RES_WIDTH:-1920}"
RES_HEIGHT="${RES_HEIGHT:-1080}"
OUTPUT_NAME="${OUTPUT_NAME:-}"

# Auto-detect output name if not set
if [ -z "$OUTPUT_NAME" ]; then
  DETECTED=$(weston-info 2>/dev/null | grep -i connector | grep -m1 connected | awk '{print $2}')
  OUTPUT_NAME="${DETECTED:-HDMI-A-1}"
  log "Auto-detected output name: $OUTPUT_NAME"
else
  log "Using predefined output: $OUTPUT_NAME"
fi

# Choose shell type
WESTON_SHELL="${WESTON_SHELL:-desktop-shell.so}"  # or kiosk-shell.so

# Write config
CONFIG_PATH="/home/gui/.config"
INI_FILE="$CONFIG_PATH/weston.ini"
mkdir -p "$CONFIG_PATH"

cat > "$INI_FILE" <<EOF
[core]
idle-time=0

[output]
name=$OUTPUT_NAME
mode=${RES_WIDTH}x${RES_HEIGHT}

[keyboard]
command=$KEYBD

[shell]
shell=$WESTON_SHELL
EOF

chown gui:gui "$INI_FILE"
chmod 644 "$INI_FILE"

log "✅ Generated $INI_FILE"
