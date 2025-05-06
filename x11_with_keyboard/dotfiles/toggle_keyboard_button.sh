#!/bin/bash
# toggle_keyboard_button.sh
SCREEN_W=$(xdpyinfo | awk '/dimensions:/ {print $2}' | cut -d 'x' -f1)
SCREEN_H=$(xdpyinfo | awk '/dimensions:/ {print $2}' | cut -d 'x' -f2)
KBD_H=$(( SCREEN_H / 3 ))
BROWSER_H=$(( SCREEN_H - KBD_H ))

if pgrep onboard >/dev/null; then
  pkill onboard
  wmctrl -r :ACTIVE: -e 0,0,0,$SCREEN_W,$SCREEN_H
else
  onboard &
  sleep 2
  wmctrl -r "Onboard" -b add,above
  wmctrl -r "Onboard" -e 0,0,$BROWSER_H,$SCREEN_W,$KBD_H
  wmctrl -r :ACTIVE: -e 0,0,0,$SCREEN_W,$BROWSER_H
fi
