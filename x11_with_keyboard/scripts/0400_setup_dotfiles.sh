#!/usr/bin/env bash
# 0400_setup_dotfiles.sh

GUI_HOME="/home/gui"

# ── Ensure Openbox config dir ─────────────
mkdir -p "$GUI_HOME/.config/openbox"

# ── Deploy .xinitrc ───────────────────────
cp xinitrc "$GUI_HOME/.xinitrc"

# ── Deploy .bash_profile ──────────────────
cp bash_profile "$GUI_HOME/.bash_profile"

# ── Deploy Openbox autostart ──────────────
cp .config/openbox/autostart "$GUI_HOME/.config/openbox/autostart"
chmod +x "$GUI_HOME/.config/openbox/autostart"

# ── Deploy GTK toggle script ──────────────
cp keyboard_toggle.py "$GUI_HOME/keyboard_toggle.py"
chmod +x "$GUI_HOME/keyboard_toggle.py"

# ── Fix permissions ───────────────────────
chown -R gui:gui "$GUI_HOME"
