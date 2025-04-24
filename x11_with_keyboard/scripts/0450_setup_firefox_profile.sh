#!/usr/bin/env bash
#0450_setup_firefox_profile.sh
set -euo pipefail

GUI_HOME="/home/gui"
PROFILE_NAME="kiosk"
PROFILE_DIR="$GUI_HOME/.mozilla/kiosk"
TEMPLATE_DIR="$(dirname "$0")/../templates"

echo "🦊 Creating Firefox profile: $PROFILE_NAME"

# Ensure Firefox isn't running
sudo -u gui pkill firefox-esr || true

# Create profile if it doesn't exist
if [ ! -d "$PROFILE_DIR" ]; then
    sudo -u gui firefox-esr -CreateProfile "$PROFILE_NAME $PROFILE_DIR"
fi

# Enable userChrome.css styling
mkdir -p "$PROFILE_DIR/chrome"

# ── Render templates ─────────────────────────────────────────

render_template() {
  local template=$1
  local output=$2
  shift 2

  cp "$template" "$output"

  for pair in "$@"; do
    key="${pair%%=*}"
    val="${pair#*=}"
    sed -i "s|{{${key}}}|${val}|g" "$output"
  done
}

render_template "$TEMPLATE_DIR/user.js.hbs" "$PROFILE_DIR/user.js" \
  PROFILE_NAME="$PROFILE_NAME" \
  PROFILE_DIR="$PROFILE_DIR"

render_template "$TEMPLATE_DIR/userChrome.css.hbs" "$PROFILE_DIR/chrome/userChrome.css" \
  PROFILE_NAME="$PROFILE_NAME" \
  PROFILE_DIR="$PROFILE_DIR"

# ── Fix permissions ──────────────────────────────────────────
chown -R gui:gui "$PROFILE_DIR"

echo "✅ Firefox kiosk profile setup complete."
