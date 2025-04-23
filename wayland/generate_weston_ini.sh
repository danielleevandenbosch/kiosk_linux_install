#!/usr/bin/env bash
# generate_weston_ini.sh
# -----------------------------------------------------------------------------
# Robust Weston configuration generator for GUI kiosk sessions.
# - Handles weston-keyboard discovery
# - Auto-detects display connector or falls back gracefully
# - Verifies and creates ~/.config/weston.ini with proper ownership
# - Logs to both terminal and /var/log/generate_weston_ini.log
# -----------------------------------------------------------------------------

set -euo pipefail

LOGFILE="/var/log/generate_weston_ini.log"
exec > >(tee -a "$LOGFILE") 2>&1
echo -e "\n=== Starting generate_weston_ini.sh at $(date) ==="

log() {
  echo -e "[weston-ini] $*"
}

fatal() {
  echo -e "[FATAL] $*" >&2
  echo "=== Failed at $(date) ==="
  exit 1
}

USER="gui"
CONFIG_PATH="/home/$USER/.config"
INI_FILE="$CONFIG_PATH/weston.ini"

# -------------------------------
# Step 1: Verify gui user exists
# -------------------------------
log "Step 1: Verifying user '$USER' exists..."
id "$USER" &>/dev/null || fatal "User '$USER' does not exist."

# -------------------------------
# Step 2: Locate weston-keyboard
# -------------------------------
log "Step 2: Locating weston-keyboard binary..."
KEYBD=$(command -v weston-keyboard || true)
if [ -z "$KEYBD" ]; then
  # fallback to dpkg scan
  KEYBD=$(dpkg -L weston | grep -m1 'weston-keyboard$' || true)
fi
[ -x "$KEYBD" ] || fatal "weston-keyboard not found or not executable. Aborting."
log "✔ Found weston-keyboard at: $KEYBD"

# -------------------------------
# Step 3: Set defaults
# -------------------------------
RES_WIDTH="${RES_WIDTH:-1920}"
RES_HEIGHT="${RES_HEIGHT:-1080}"
WESTON_SHELL="${WESTON_SHELL:-desktop-shell.so}"

# -------------------------------
# Step 4: Auto-detect connector
# -------------------------------
log "Step 4: Detecting output connector..."
OUTPUT_NAME="${OUTPUT_NAME:-}"
if [ -z "$OUTPUT_NAME" ]; then
  DETECTED=$(weston-info 2>/dev/null | grep -iE 'connector' | grep -m1 connected | awk '{print $2}' || true)
  OUTPUT_NAME="${DETECTED:-HDMI-A-1}"
  if [ -z "$DETECTED" ]; then
    log "⚠️ Could not auto-detect output. Falling back to HDMI-A-1"
  else
    log "✔ Auto-detected connector: $OUTPUT_NAME"
  fi
else
  log "✔ Using pre-set OUTPUT_NAME: $OUTPUT_NAME"
fi

# -------------------------------
# Step 5: Ensure config dir
# -------------------------------
log "Step 5: Ensuring $CONFIG_PATH exists and is writable..."
mkdir -p "$CONFIG_PATH" || fatal "Failed to create $CONFIG_PATH"
chown "$USER:$USER" "$CONFIG_PATH"
chmod 700 "$CONFIG_PATH"

# -------------------------------
# Step 6: Write weston.ini
# -------------------------------
log "Step 6: Writing weston.ini to $INI_FILE"
touch "$INI_FILE" || fatal "Failed to create $INI_FILE (permissions?)"

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

# -------------------------------
# Step 7: Permissions
# -------------------------------
chown "$USER:$USER" "$INI_FILE"
chmod 644 "$INI_FILE"
log "✔ Successfully wrote $INI_FILE with correct ownership"

echo -e "\n=== Finished generate_weston_ini.sh at $(date) ==="

log "=== Finished generate_weston_ini.sh at $(date) ==="
