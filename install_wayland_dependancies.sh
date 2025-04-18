#!/usr/bin/env bash
# install_wayland_dependancies.sh
# Installs all required packages for Wayland kiosk + admin tools

set -euo pipefail

log() { echo -e "[dep-installer] $*"; }

# Determine package manager
if command -v apt &>/dev/null
then
  PKG_MGR="apt"
  UPDATE_CMD="apt update -y"
  INSTALL_CMD="apt install -y"
elif command -v dnf &>/dev/null
then
  PKG_MGR="dnf"
  UPDATE_CMD="dnf check-update || true"
  INSTALL_CMD="dnf install -y"
elif command -v pacman &>/dev/null
then
  PKG_MGR="pacman"
  UPDATE_CMD="pacman -Sy"
  INSTALL_CMD="pacman -S --noconfirm"
else
  echo "❌ Unsupported package manager"
  exit 1
fi

log "Using $PKG_MGR for installation."
log "Updating package lists..."
$UPDATE_CMD

# Core kiosk packages
PACKAGES=(
  chromium
  maliit-keyboard
  dbus
)

# Try to include weston or weston-launch depending on availability
if [ "$PKG_MGR" = "apt" ]; then
  if apt-cache show weston &>/dev/null; then
    PACKAGES+=(weston)
  elif apt-cache show weston-launch &>/dev/null; then
    PACKAGES+=(weston-launch)
  else
    echo "❌ Neither weston nor weston-launch available in apt." >&2
    exit 1
  fi
elif [ "$PKG_MGR" = "dnf" ]; then
  PACKAGES+=(weston)
elif [ "$PKG_MGR" = "pacman" ]; then
  PACKAGES+=(weston)
fi

# Networking + admin tools
PACKAGES+=(
  network-manager
  openssh-server
  openssh-client
  mosh
  neofetch
  htop
  vim
  zsh
  unzip
  curl
  wget
  git
  figlet
  acpi
)

log "Installing packages: ${PACKAGES[*]}"
$INSTALL_CMD "${PACKAGES[@]}"

log "Dependencies installed."
exit 0

