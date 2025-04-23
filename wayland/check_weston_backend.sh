#!/usr/bin/env bash
# check_weston_backend.sh

log() { echo -e "[backend-check] $*"; }

# Check that /dev/dri/card0 exists and is accessible
if [ ! -e /dev/dri/card0 ]; then
    log "❌ /dev/dri/card0 does not exist. DRM not available?"
    exit 1
fi

if ! getent group video | grep -q '\bgui\b'; then
    log "⚠️ Adding user 'gui' to 'video' group..."
    usermod -aG video gui
fi

# Check permissions
if [ ! -r /dev/dri/card0 ]; then
    log "❌ gui user may not have permission to read /dev/dri/card0"
    log "Try: chmod 666 /dev/dri/card0 (TEMP TEST ONLY)"
    exit 1
fi

log "✅ DRM device available and permissions look good"
exit 0
