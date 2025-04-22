SOCKET=$(find /run/user/1001 -maxdepth 1 -type s -name 'wayland-*' | head -n1)
export XDG_RUNTIME_DIR=/run/user/1001
export WAYLAND_DISPLAY=$(basename "$SOCKET")

sudo -u gui \
  XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
  WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
  dbus-run-session -- flatpak run org.chromium.Chromium --ozone-platform=wayland
