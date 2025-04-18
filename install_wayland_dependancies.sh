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
  weston
  weston-launch
  chromium
  maliit-keyboard
  dbus
)

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
