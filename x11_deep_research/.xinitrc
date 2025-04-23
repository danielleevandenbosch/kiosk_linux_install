#!/bin/sh
# Disable screen blanking and power management
xset -dpms       # disable DPMS power management
xset s off       # disable screen saver
xset s noblank   # prevent screen blanking
xset r off       # disable key repeat to prevent stuck keys

# Export input method for Matchbox (auto-show on focus)
export GTK_IM_MODULE=matchbox-keyboard
export QT_IM_MODULE=matchbox-keyboard
# (Above ensures the Matchbox IM module is used by GTK/Qt apps, triggering the keyboard)

# Start the Matchbox on-screen keyboard in daemon mode (no visible window yet)
matchbox-keyboard -d &           # -d = daemon mode for on-demand pop-up

# Start the Matchbox window manager (no window title bars, suits kiosk)
matchbox-window-manager -use_titlebar no &

# Launch the browser in kiosk mode (full screen) pointing to the desired webpage
# Use a loop to restart if the browser crashes or exits
while true; do
    chromium --app='https://google.com' \
             --kiosk --noerrdialogs --incognito \
             --disable-session-crashed-bubble --disable-infobars --no-first-run
    sleep 5    # short delay before restarting if needed
done