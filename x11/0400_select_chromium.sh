#!/usr/bin/env bash


### scripts/04_select_chromium.sh
if dpkg -s chromium &>/dev/null
then
  export CHROMIUM_CMD="chromium"
elif dpkg -s chromium-browser &>/dev/null
then
  export CHROMIUM_CMD="chromium-browser"
else
  echo "Neither 'chromium' nor 'chromium-browser' is installed or installable. Aborting."
  exit 1
fi