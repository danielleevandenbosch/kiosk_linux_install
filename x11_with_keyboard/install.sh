#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script as root or via sudo."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Running Kiosk Linux setup from: $SCRIPT_DIR"

# ── Step 1: Create kiosk user ───────────────────────────────
echo "Step 1: Create kiosk user"
source "$SCRIPT_DIR/scripts/0100_create_gui_user.sh"

# ── Step 2: Setup autologin for user gui ────────────────────
echo "Step 2: Setup autologin for user gui"
source "$SCRIPT_DIR/scripts/0200_setup_autologin.sh"

# ── Step 3: Install required packages ───────────────────────
echo "Step 3: Install required packages"
source "$SCRIPT_DIR/scripts/0300_install_packages.sh"

# ── Step 4: Copy all dotfiles/scripts to /home/gui ──────────
echo "Step 4: Copy all dotfiles/scripts to /home/gui"
source "$SCRIPT_DIR/scripts/0400_setup_dotfiles.sh"

# ── Step 4.5: firefox setup ──────────
echo "Step 4.5: firefox setup"
source "$SCRIPT_DIR/scripts/0450_setup_firefox_profile.sh"


echo "Kiosk install complete. You can now reboot."
