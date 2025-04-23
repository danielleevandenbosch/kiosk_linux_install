#!/usr/bin/env bash

### scripts/03_install_packages.sh
echo "Updating package lists..."
apt-get update -y

PACKAGES=(
  xorg
  xserver-xorg-core 
  xserver-xorg-video-fbdev
  xserver-xorg-input-libinput 
  xinit
  wmctrl
  chromium
  chromium-browser
  unclutter
  matchbox-window-manager
  matchbox-keyboard 
  matchbox-keyboard-im
  network-manager
  openssh-client
  openssh-server
  zsh
  vim
  neofetch
  htop
  mosh
)

for pkg in "${PACKAGES[@]}"
do
  if dpkg -s "$pkg" &>/dev/null
  then
    echo "Package '$pkg' is already installed."
  else
    apt-get install -y "$pkg" || echo "Package '$pkg' not found or could not be installed."
  fi
done