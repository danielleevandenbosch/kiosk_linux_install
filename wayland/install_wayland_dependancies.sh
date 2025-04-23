#!/usr/bin/env bash
# install_wayland_dependancies.sh
# Installs all required packages for Wayland kiosk + admin tools and enables seatd

set -euo pipefail

log() { echo -e "[dep-installer] $*"; }

# Determine package manager
if command -v apt &>/dev/null
then
  PKG_MGR="apt"
  UPDATE_CMD="apt update -y"
  INSTALL_CMD="apt install -y"
  REMOVE_CMD="apt purge -y"
elif command -v dnf &>/dev/null
then
  PKG_MGR="dnf"
  UPDATE_CMD="dnf check-update || true"
  INSTALL_CMD="dnf install -y"
  REMOVE_CMD="dnf remove -y"
elif command -v pacman &>/dev/null
then
  PKG_MGR="pacman"
  UPDATE_CMD="pacman -Sy"
  INSTALL_CMD="pacman -S --noconfirm"
  REMOVE_CMD="pacman -Rns --noconfirm"
else
  echo "❌ Unsupported package manager"
  exit 1
fi

log "Using $PKG_MGR for installation."
log "Updating package lists..."
$UPDATE_CMD

# ── 0. Remove any system Chromium ───────────────────────────────────────
log "Removing any existing Chromium installs..."
$REMOVE_CMD chromium || true
$REMOVE_CMD chromium-browser || true

# ── 1. Install core packages ─────────────────────────────────────────────
PACKAGES=(
  dbus
  maliit-keyboard
  weston
  foot
  glmark2-wayland
)

# Weston or Weston-launch
if [ "$PKG_MGR" = "apt" ]; then
  if apt-cache show weston &>/dev/null; then
    PACKAGES+=(weston)
  elif apt-cache show weston-launch &>/dev/null; then
    PACKAGES+=(weston-launch)
  else
    echo "❌ Neither weston nor weston-launch available in apt." >&2
    exit 1
  fi
else
  PACKAGES+=(weston)
fi

# Networking + Admin tools
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
  flatpak
  seatd
)

log "Installing packages: ${PACKAGES[*]}"
$INSTALL_CMD "${PACKAGES[@]}"

# ── 2. Install Chromium via Flatpak ──────────────────────────────────────
log "Installing Chromium from Flatpak..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.chromium.Chromium

# ── 3. Enable seatd daemon ───────────────────────────────────────────────
log "Enabling seatd.service..."
systemctl enable seatd.service
systemctl start seatd.service
log "✅ seatd is now enabled and running."

log "✅ All dependencies installed and seatd activated."
exit 0

