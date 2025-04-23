# Disable screen blanking + power management
xset s off -dpms &

# Hide mouse pointer after 300s of inactivity
unclutter -idle 300 &

# Force HDMI-1 to the chosen resolution, disable HDMI-2 (if present)
xrandr --output HDMI-1 --mode 1920x1080 --output HDMI-2 --off &

# Minimal window manager so that Chromium can truly go fullscreen
matchbox-window-manager &

# Wait a bit to ensure splash is visible
sleep 3

# Launch Chromium in kiosk mode
chromium --kiosk --no-first-run --disable-infobars --disable-session-crashed-bubble https://i4.intouchmonitoring.com
