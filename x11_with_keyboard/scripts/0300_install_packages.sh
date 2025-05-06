#!/usr/bin/env bash

### scripts/03_install_packages.sh
echo "Updating package lists..."
apt-get update -y
# 0300_install_packages.sh

PACKAGES=(
  xorg
  xserver-xorg-core 
  xserver-xorg-video-fbdev
  xserver-xorg-input-libinput 
  xinit
  xdotool
  dbus-x11
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
  yad
  onboard
  openbox
  python3-gi
  gir1.2-gtk-3.0
  firefox-esr
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
