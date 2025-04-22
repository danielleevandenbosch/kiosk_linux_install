#!/usr/bin/env bash
# generate_weston_ini.sh
# -----------------------------------------------------------------------------
# Creates a well-structured Weston configuration file (~/.config/weston.ini)
# for the 'gui' user. This file customizes the Wayland session launched
# by Weston with kiosk-appropriate defaults and ensures compatibility with
# touchscreens, idle settings, and specific display configurations.
# -----------------------------------------------------------------------------

set -euo pipefail

log() {
  echo -e "[weston-ini] $*"
}

USER=gui
CONFIG_PATH="/home/$USER/.config"
INI_FILE="$CONFIG_PATH/weston.ini"

# 1. Locate the weston-keyboard binary
KEYBD=$(dpkg -L weston | grep -m1 weston-keyboard) || {
  log "❌ Error: weston-keyboard not found. Is Weston installed?"
  exit 1
}

# 2. Set default or inherited resolution and shell type
RES_WIDTH="${RES_WIDTH:-1920}"
RES_HEIGHT="${RES_HEIGHT:-1080}"
WESTON_SHELL="${WESTON_SHELL:-desktop-shell.so}"  # Can be kiosk-shell.so

# 3. Detect connected output if none specified
OUTPUT_NAME="${OUTPUT_NAME:-}"
if [ -z "$OUTPUT_NAME" ]; then
  DETECTED=$(weston-info 2>/dev/null | grep -i connector | grep -m1 connected | awk '{print $2}')
  OUTPUT_NAME="${DETECTED:-HDMI-A-1}"
  log "Auto-detected output name: $OUTPUT_NAME"
else
  log "Using predefined output: $OUTPUT_NAME"
fi

# 4. Ensure the .config directory exists and is owned by the gui user
log "Creating $CONFIG_PATH if missing"
mkdir -p "$CONFIG_PATH"
chown "$USER:$USER" "$CONFIG_PATH"

# 5. Write the Weston configuration to weston.ini
log "Writing configuration to $INI_FILE"
cat > "$INI_FILE" <<EOF
[core]
# Disable screen blanking / power save
idle-time=0

[output]
# Force display resolution and monitor output
name=$OUTPUT_NAME
mode=${RES_WIDTH}x${RES_HEIGHT}

[keyboard]
# Start the Weston on-screen keyboard
command=$KEYBD

[shell]
# Set the shell to either desktop-shell.so or kiosk-shell.so
shell=$WESTON_SHELL
EOF

# 6. Set permissions and ownership
chown "$USER:$USER" "$INI_FILE"
chmod 644 "$INI_FILE"

log "✅ Successfully generated Weston configuration at $INI_FILE"
