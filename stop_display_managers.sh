#!/usr/bin/env bash
# stop_display_managers.sh
# Nukes nearly all known and obscure display managers.
# Disables, stops, and masks them to prevent interference with Weston or DRM.

set -euo pipefail

log() { echo -e "[display-manager] $*"; }

log "🚫 Initiating full display manager lockdown..."

DM_LIST=(
  gdm gdm3             # GNOME
  lightdm              # XFCE / lightweight
  sddm                 # KDE / Plasma
  lxdm                 # LXDE
  xdm                  # Traditional X11
  nodm                 # Autologin manager
  slim                 # Lightweight login manager
  cdm                  # Console Display Manager
  entrance             # Enlightenment
  wdm                  # WINGs login manager
  ly                   # TUI-based DM (Rust)
  tbsm                 # TUI-based session manager
  mdm                  # Linux Mint
  dtlogin              # Old Solaris / CDE
  altdm                # Experimental Arch/Alpine
  canopy               # Some kiosk setups
  clem                 # Cinnamon experimental
  mingetty             # Might get configured for graphical tty autologin
  agetty               # Also TTY autologin source (mostly harmless)
  nssdm                # NixOS experimental
  console-login        # Sometimes abused for DM in embedded
  seatd                # Could interfere on wayland backends
)

for svc in "${DM_LIST[@]}"
do
    if systemctl list-unit-files | grep -q "^$svc.service"; then
        log "🧠 Found $svc.service"
        systemctl disable "$svc" 2>/dev/null && log "  ⛔ Disabled $svc"
        systemctl stop "$svc"    2>/dev/null && log "  📴 Stopped $svc"
        systemctl mask "$svc"    2>/dev/null && log "  🔒 Masked $svc"
    fi
done

log "✅ Display manager purge complete."
