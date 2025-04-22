#!/usr/bin/env bash
# test_chromium.sh
# Launch Chromium Wayland Kiosk test without portal sandboxing

echo "[chromium-test] 🚀 Starting Chromium Wayland test..."

SOCKET=$(find /run/user/1001 -maxdepth 1 -type s -name 'wayland-*' | head -n1)
export XDG_RUNTIME_DIR=/run/user/1001
export WAYLAND_DISPLAY=$(basename "$SOCKET")

sudo -u gui \
  env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
      WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  flatpak run \
    --no-talk-name=org.freedesktop.portal.Documents \
    --no-talk-name=org.freedesktop.portal.Fuse \
    --env=GTK_USE_PORTAL=0 \
    --env=MOZ_ENABLE_WAYLAND=1 \
    --env=GDK_BACKEND=wayland \
    org.chromium.Chromium \
    --ozone-platform=wayland \
    --disable-features=UseOzonePlatformForVideo \
    --enable-features=UseOzonePlatform

