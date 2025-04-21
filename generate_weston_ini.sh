#!/usr/bin/env bash
# generate_weston_ini.sh
# -----------------------------------------------------------------------------
# This script creates a Weston configuration file (~/.config/weston.ini)
# for the 'gui' user. Weston is a reference Wayland compositor, and this
# file is used to configure session-level behavior for the Wayland session.
#
# Without this file, Weston will attempt to launch with default settings,
# which may result in improper resolution, unresponsive input devices,
# or a missing on-screen keyboard in kiosk environments.
#
# This file ensures the following:
# - Weston does not idle or blank the screen
# - A consistent output resolution is used
# - The on-screen keyboard (OSK) is properly launched
# - Configuration is isolated to the 'gui' user session
# -----------------------------------------------------------------------------

set -euo pipefail

# Locate the path to weston-keyboard binary for on-screen keyboard support.
KEYBD=$(dpkg -L weston | grep -m1 weston-keyboard) || {
  echo "❌ weston-keyboard not found" >&2
  exit 1
}

# These can be overridden before calling the script from the ricer installer
RES_WIDTH="${RES_WIDTH:-1920}"      # Default width if not otherwise specified
RES_HEIGHT="${RES_HEIGHT:-1080}"    # Default height if not otherwise specified
OUTPUT_NAME="${OUTPUT_NAME:-HDMI-A-1}"  # Name of the output device to configure
                                       # Use `weston-info | grep -i connector` if unsure

# Ensure the configuration directory exists for the gui user
sudo -u gui mkdir -p /home/gui/.config

# Write out the Weston config file with relevant sections
cat > /home/gui/.config/weston.ini <<EOF
[core]
# Prevent screen from going blank (no screensaver or power save)
idle-time=0

[output]
# Force Weston to use a specific resolution on a known output
name=$OUTPUT_NAME
mode=${RES_WIDTH}x${RES_HEIGHT}

[keyboard]
# Launch on-screen keyboard, useful for touchscreen kiosk setups
command=$KEYBD
EOF

# Set proper ownership and permissions
chown gui:gui /home/gui/.config/weston.ini
chmod 644 /home/gui/.config/weston.ini
