SOCKET=$(find /run/user/1001 -maxdepth 1 -type s -name 'wayland-*' | head -n1)
export XDG_RUNTIME_DIR=/run/user/1001
export WAYLAND_DISPLAY=$(basename "$SOCKET")

sudo -u gui dbus-run-session -- flatpak run org.chromium.Chromium --ozone-platform=wayland
