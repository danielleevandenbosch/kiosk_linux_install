#!/usr/bin/env bash
# weston_check.sh
# Determines the correct Weston binary path (weston-launch or weston)

set -euo pipefail

log() {
  echo -e "[weston-check] $*"
}

# Search for valid Weston launcher binary
for bin in \
  "$(command -v weston-launch 2>/dev/null)" \
  "/usr/libexec/weston-launch" \
  "$(command -v weston 2>/dev/null)"
do
  if [ -x "$bin" ]; then
    echo "$bin"
    exit 0
  fi
done

log "weston-launch or weston not found. Please install one."
exit 1
