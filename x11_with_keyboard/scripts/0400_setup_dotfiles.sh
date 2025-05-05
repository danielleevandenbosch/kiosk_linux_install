#!/usr/bin/env bash
# 0400_setup_dotfiles.sh

set -euo pipefail

GUI_HOME="/home/gui"
DOTFILES_DIR="$(dirname "$0")/../dotfiles"

# ── 0400a Ensure Openbox config dir ─────────────
echo "0400a Ensure Openbox config dir"
mkdir -p "$GUI_HOME/.config/openbox"

# ── Deploy .xinitrc ───────────────────────
echo "Deploy .xinitrc"
cp "$DOTFILES_DIR/.xinitrc" "$GUI_HOME/.xinitrc"

# ── Deploy .bash_profile ──────────────────
echo "Deploy .bash_profile"
cp "$DOTFILES_DIR/.bash_profile" "$GUI_HOME/.bash_profile"

# ── Deploy Openbox autostart ──────────────
echo "Deploy Openbox autostart"
cp "$DOTFILES_DIR/autostart" "$GUI_HOME/.config/openbox/autostart"
chmod +x "$GUI_HOME/.config/openbox/autostart"

# ── Deploy GTK toggle script ──────────────
echo "Deploy GTK toggle script"
cp "$DOTFILES_DIR/keyboard_toggle.py" "$GUI_HOME/keyboard_toggle.py"
chmod +x "$GUI_HOME/keyboard_toggle.py"

# -- Deploy the toggle button for the keyboard script-----
echo "Deploy the toggle button for the keyboard script"
cp "$DOTFILES_DIR/toggle_keyboard_button.sh" "$GUI_HOME/toggle_keyboard_button.sh"
chmod +x "$GUI_HOME/toggle_keyboard_button.sh"

# ── Fix permissions ───────────────────────
echo "Fix Permissions"
chown -R gui:gui "$GUI_HOME"
