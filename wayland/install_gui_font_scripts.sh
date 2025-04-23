#!/usr/bin/env bash
# install_gui_font_scripts.sh — installs font toggle scripts for 'gui' user using pure bash + sudo access

set -euo pipefail

GUI_USER=gui
FONT_DIR="/home/$GUI_USER/tty-font-toggle"
SUDOERS_FILE="/etc/sudoers.d/tty-font-toggle-$GUI_USER"

mkdir -p "$FONT_DIR"

# Create font changing scripts
cat > "$FONT_DIR/font_small.sh" <<'EOF'
#!/usr/bin/env bash
exec sudo /usr/bin/setfont /usr/share/consolefonts/Lat2-Terminus12x6.psf.gz
EOF

cat > "$FONT_DIR/font_medium.sh" <<'EOF'
#!/usr/bin/env bash
exec sudo /usr/bin/setfont /usr/share/consolefonts/Lat2-Terminus16.psf.gz
EOF

cat > "$FONT_DIR/font_large.sh" <<'EOF'
#!/usr/bin/env bash
exec sudo /usr/bin/setfont /usr/share/consolefonts/Lat2-Terminus20x10.psf.gz
EOF

chmod +x "$FONT_DIR"/font_*.sh
chown -R "$GUI_USER:$GUI_USER" "$FONT_DIR"

# Create sudoers file allowing only those scripts to be run without password
cat > "$SUDOERS_FILE" <<EOF
$GUI_USER ALL=(ALL) NOPASSWD: $FONT_DIR/font_small.sh
$GUI_USER ALL=(ALL) NOPASSWD: $FONT_DIR/font_medium.sh
$GUI_USER ALL=(ALL) NOPASSWD: $FONT_DIR/font_large.sh
EOF

chmod 440 "$SUDOERS_FILE"
echo "[✓] Font toggle scripts installed in $FONT_DIR for user '$GUI_USER'"

# Example usage as gui:
#   ~/tty-font-toggle/font_small.sh
