#!/usr/bin/env bash

### scripts/06_write_bash_profile.sh
cat <<'EOF' > /home/gui/.bash_profile
clear

cat <<'SPLASH'
  _      _                    _  ___           _                                                                 
 | |    (_)                  | |/ (_)         | |                                                                
 | |     _ _ __  _   ___  __ | ' / _  ___  ___| | __                                                             
 | |    | | '_ \| | | \ \/ / |  < | |/ _ \/ __| |/ /                                                             
 | |____| | | | | |_| |>  <  | . \| | (_) \__ \   <                                                              
 |______|_|_| |_|\__,_/_/\_\ |_|\_\_|\___/|___/_|\_\   

Daniel Van Den Bosch Kiosk Linux
https://github.com/danielleevandenbosch/kiosk_linux_install
SPLASH

echo "battery at: " | figlet 
acpi | grep -oP '[0-9]+%' | figlet

sleep 30

if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]
then
  startx
fi
EOF

chown gui:gui /home/gui/.bash_profile
chmod 644 /home/gui/.bash_profile