#!/usr/bin/env bash
# generate_weston_ini.sh
# -----------------------------------------------------------------------------
# Generates /home/gui/.config/weston.ini and logs all actions to both screen
# and /var/log/generate_weston_ini.log for troubleshooting.
# -----------------------------------------------------------------------------

set -euo pipefail

LOGFILE="/var/log/generate_weston_ini.log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "=== Starting generate_weston_ini.sh at $(date) ==="

log() {
  echo -e "[weston-ini] $*"
}

USER=gui
CONFIG_PATH="/home/$USER/.config"
INI_FILE="$CONFIG_PATH/weston.ini"

log "Step 1: Locating weston-keyboard binary..."
KEYBD=$(dpkg -L weston | grep -m1 weston-keyboard) || {
  log "❌ Error: weston-keyboard not found. Aborting."
  exit 1
}
log "✔ Found weston-keyboard at: $KEYBD"

RES_WIDTH="${RES_WIDTH:-1920}"
RES_HEIGHT="${RES_HEIGHT:-1080}"
WESTON_SHELL="${WESTON_SHELL:-desktop-shell.so}"

log "Step 2: Detecting output connector..."
OUTPUT_NAME="${OUTPUT_NAME:-}"
if [ -z "$OUTPUT_NAME" ]; then
  DETECTED=$(weston-info 2>/dev/null | grep -i connector | grep -m1 connected | awk '{print $2}')
  OUTPUT_NAME="${DETECTED:-HDMI-A-1}"
  log "✔ Auto-detected output name: $OUTPUT_NAME"
else
  log "✔ Using specified output: $OUTPUT_NAME"
fi

log "Step 3: Ensuring $CONFIG_PATH exists and is writable..."
mkdir -p "$CONFIG_PATH"
chown "$USER:$USER" "$CONFIG_PATH"
chmod 700 "$CONFIG_PATH"

log "Step 4: Writing to $INI_FILE"
touch "$INI_FILE" || {
  log "❌ Failed to create $INI_FILE. Check permissions."
  exit 1
}

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

chown "$USER:$USER" "$INI_FILE"
chmod 644 "$INI_FILE"

log "✅ Successfully created $INI_FILE"
log "=== Finished generate_weston_ini.sh at $(date) ==="
