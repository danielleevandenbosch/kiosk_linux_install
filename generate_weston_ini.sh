#!/usr/bin/env bash
# generate_weston_ini.sh
# -----------------------------------------------------------------------------
# Generates /home/gui/.config/weston.ini for the Weston Wayland session.
# Ensures proper config for kiosk setups with idle disabled, fixed resolution,
# on-screen keyboard, and a specified shell.
# This version avoids sudo -u and assumes root execution in the ricer context.
# -----------------------------------------------------------------------------

set -euo pipefail

log() {
  echo -e "[weston-ini] $*"
}

USER=gui
CONFIG_PATH="/home/$USER/.config"
INI_FILE="$CONFIG_PATH/weston.ini"

# 1. Confirm weston-keyboard binary exists
KEYBD=$(dpkg -L weston | grep -m1 weston-keyboard) || {
  log "❌ weston-keyboard not found. Is Weston installed?"
  exit 1
}

# 2. Resolution and shell defaults
RES_WIDTH="${RES_WIDTH:-1920}"
RES_HEIGHT="${RES_HEIGHT:-1080}"
WESTON_SHELL="${WESTON_SHELL:-desktop-shell.so}"

# 3. Detect output name (HDMI-A-1 fallback if not found)
OUTPUT_NAME="${OUTPUT_NAME:-}"
if [ -z "$OUTPUT_NAME" ]; then
  DETECTED=$(weston-info 2>/dev/null | grep -i connector | grep -m1 connected | awk '{print $2}')
  OUTPUT_NAME="${DETECTED:-HDMI-A-1}"
  log "Auto-detected output: $OUTPUT_NAME"
else
  log "Using predefined output: $OUTPUT_NAME"
fi

# 4. Ensure the config directory exists and is owned by gui
log "Creating $CONFIG_PATH and fixing permissions..."
mkdir -p "$CONFIG_PATH"
chown "$USER:$USER" "$CONFIG_PATH"
chmod 700 "$CONFIG_PATH"

# 5. Write the weston.ini config file
log "Writing config to $INI_FILE"
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

# 6. Final ownership and access settings
chown "$USER:$USER" "$INI_FILE"
chmod 644 "$INI_FILE"

log "✅ Successfully created $INI_FILE"
