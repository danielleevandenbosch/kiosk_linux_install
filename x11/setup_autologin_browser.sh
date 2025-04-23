#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]
then
  echo "Please run this script as root or via sudo."
  exit 1
fi

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

source "$SCRIPT_DIR/scripts/0100_create_gui_user.sh"
source "$SCRIPT_DIR/scripts/0200_setup_autologin.sh"
source "$SCRIPT_DIR/scripts/0300_install_packages.sh"
source "$SCRIPT_DIR/scripts/0400_select_chromium.sh"
source "$SCRIPT_DIR/scripts/0500_prompt_resolution_url.sh"
source "$SCRIPT_DIR/scripts/0600_write_bash_profile.sh"
source "$SCRIPT_DIR/scripts/0700_write_xinitrc.sh"
source "$SCRIPT_DIR/scripts/0800_finalize_setup.sh"