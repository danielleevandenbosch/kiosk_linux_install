#!/usr/bin/env bash
# get_kiosk_input.sh
# Prompts user for resolution and URL, outputs to stdout for sourcing

set -euo pipefail

read -rp "Resolution (WxH) [1920x1080]: " RES
RES="${RES:-1920x1080}"

if ! [[ "$RES" =~ ^[0-9]+x[0-9]+$ ]]; then
  echo "❌ Invalid resolution format" >&2
  exit 1
fi

W=${RES%x*}
H=${RES#*x}

read -rp "URL to open [https://example.com]: " URL
URL="${URL:-https://example.com}"

# Output to be sourced
echo "W=$W"
echo "H=$H"
echo "URL=\"$URL\""
