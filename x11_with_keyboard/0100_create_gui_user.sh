#!/usr/bin/env bash

### scripts/01_create_gui_user.sh
if ! id -u gui >/dev/null 2>&1
then
  useradd -m -s /bin/bash gui
  echo "gui:gui" | chpasswd
fi

usermod -aG dialout gui