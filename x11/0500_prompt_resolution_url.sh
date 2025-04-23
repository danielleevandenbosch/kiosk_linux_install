#!/usr/bin/env bash

### scripts/05_prompt_resolution_url.sh
echo "Select a resolution mode for HDMI-1 (common combos):"
echo "1) 1080p (1920x1080)"
echo "2) 4K (3840x2160)"
echo "3) Custom"

read -rp "Enter choice [1-3]: " CHOICE

case "$CHOICE" in
  1)
    RESOLUTION="1920x1080"
    ;;
  2)
    RESOLUTION="3840x2160"
    ;;
  3)
    read -rp "Enter custom resolution (e.g. 1920x1080): " RESOLUTION
    ;;
  *)
    echo "Invalid choice, defaulting to 1920x1080."
    RESOLUTION="1920x1080"
    ;;
esac

read -rp "Enter the URL to open in Chromium (default: https://example.com): " TARGET_URL
if [ -z "$TARGET_URL" ]
then
  TARGET_URL="https://example.com"
fi

export RESOLUTION
export TARGET_URL