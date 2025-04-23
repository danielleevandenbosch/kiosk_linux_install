#!/usr/bin/env bash
# generate_bash_profile.sh
# Writes ~/.bash_profile for gui user to launch the kiosk and kill display managers

set -euo pipefail

log()
{
  echo -e "[bash-profile] $*"
}

TARGET="/home/gui/.bash_profile"

cat > "$TARGET" <<'EOF'
if [[ -z $WAYLAND_DISPLAY && $(tty) = /dev/tty1 ]]; then
    # Re-nuke display managers at login
    if [ -x "$HOME/stop_display_managers.sh" ]; then
        echo '[.bash_profile] Killing any active display managers...'
        bash "$HOME/stop_display_managers.sh"
    fi

    ~/start_kiosk.sh
fi
EOF

chown gui:gui "$TARGET"
chmod 644 "$TARGET"

log "✅ Created .bash_profile for gui with display manager purge"
