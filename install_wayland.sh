sudo tee install_kiosk_full.sh >/dev/null <<'SCRIPT'
#!/usr/bin/env bash
##############################################################################
#  Daniel Van Den Bosch · FULL Kiosk Installer (Wayland first, X11 fallback) #
#  Logs everything to /var/log/kiosk_install.log                             #
##############################################################################
set -euo pipefail
INSTALL_LOG=/var/log/kiosk_install.log
exec > >(tee -a "$INSTALL_LOG") 2>&1
echo "===== INSTALL $(date) ====="

# ───────────────────────────── Helpers ──────────────────────────────────────
die(){ echo "❌  $*" ; exit 1; }

pkg(){ dpkg -s "$1" &>/dev/null || { echo "• Installing $1"; apt-get install -y "$1"; } || echo "⚠️  (skipped $1)"; }

as_gui(){ sudo -u gui bash -c "$*"; }

# ───────────────────────────── Root check ───────────────────────────────────
[ "$(id -u)" -eq 0 ] || die "Run as root (sudo)."

# ───────────────────────────── User setup ───────────────────────────────────
if ! id -u gui &>/dev/null; then
  echo "• Creating user gui"
  useradd -m -s /bin/bash gui
  echo "gui:gui" | chpasswd
fi
usermod -aG dialout gui

# ───────────────────────────── Autologin TTY1 ───────────────────────────────
echo "• Setting autologin on tty1"
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin gui --noclear %I $TERM
EOF

# ───────────────────────────── Package install ─────────────────────────────
echo "• Updating apt repositories"
apt-get update -y
PKGS=(weston xserver-xorg xinit matchbox-window-manager maliit-keyboard
      onboard xdotool chromium unclutter openssh-server zsh vim htop neofetch)
for p in "${PKGS[@]}"; do pkg "$p"; done
command -v chromium >/dev/null || die "Chromium still missing"

# ───────────────────────────── Ask user config ─────────────────────────────
read -rp "Resolution  (e.g. 1920x1080) [default 1920x1080]: " RES
RES=${RES:-1920x1080}
[[ $RES =~ ^[0-9]+x[0-9]+$ ]] || die "Bad resolution format"
read -rp "URL to load [default https://example.com]: " URL
URL=${URL:-https://example.com}
W=${RES%x*}; H=${RES#*x}
echo "Config: ${W}x${H}  URL: $URL"

# ───────────────────────────── Weston config ───────────────────────────────
echo "• Writing ~/.config/weston.ini"
as_gui "mkdir -p ~/.config && cat >~/.config/weston.ini <<INI
[core]
idle-time=0

[keyboard]
command=/usr/libexec/weston-keyboard
INI"

# ───────────────────────────── Onboard watcher (X11) ───────────────────────
echo "• Writing onboard focus watcher"
as_gui "cat >~/onboard_watcher.sh <<'OW'
#!/usr/bin/env bash
LOG=\$HOME/kiosk-x11.log
echo \"[watcher] start \$(date)\" >>\$LOG
while true
do
  wid=\$(xdotool getwindowfocus)
  class=\$(xprop -id \"\$wid\" WM_CLASS 2>/dev/null | awk -F\\\" '{print \$4}')
  echo \$(date +%T) class:\$class >>\$LOG
  if echo \"\$class\" | grep -qiE 'chromium|chrome'
  then pgrep -x onboard >/dev/null || { echo \$(date +%T) 'launch onboard'>>\$LOG; onboard & }
  else pkill onboard 2>/dev/null
  fi
  sleep 1
done
OW
chmod +x ~/onboard_watcher.sh"

# ───────────────────────────── Xsession file ───────────────────────────────
echo "• Writing .xsession (Matchbox + Chromium)"
as_gui "cat >~/.xsession <<XS
#!/bin/sh
export DISPLAY=:1
xset s off -dpms &
unclutter -idle 300 &
matchbox-window-manager &
(sleep 5 && ~/onboard_watcher.sh) &
exec chromium --kiosk --no-first-run --disable-infobars --disable-session-crashed-bubble --enable-touch-events \"$URL\"
XS
chmod +x ~/.xsession"

# ───────────────────────────── Main kiosk launcher ─────────────────────────
echo "• Writing start_kiosk.sh"
as_gui "cat >~/start_kiosk.sh <<'SK'
#!/usr/bin/env bash
export XDG_RUNTIME_DIR=/run/user/\$(id -u)
export QT_QPA_PLATFORM=wayland
WAYLOG=\$HOME/kiosk-wayland.log; XLOG=\$HOME/kiosk-x11.log
echo \"[kiosk] boot \$(date)\" >\$WAYLOG

# choose backend
if [ -e /dev/dri/card0 ]; then BACKEND=drm-backend.so; else BACKEND=fbdev-backend.so; fi
dbus-run-session -- weston --backend=\$BACKEND --width=$W --height=$H --idle-time=0 >>\$WAYLOG 2>&1 &
for i in {1..6}; do [ -S \$XDG_RUNTIME_DIR/wayland-0 ] && READY=1 && break; sleep 1; done

if [ \"\$READY\" = 1 ]; then
  echo \"[kiosk] Weston OK -> launching maliit + Chromium\" >>\$WAYLOG
  maliit-server >>\$WAYLOG 2>&1 &
  exec chromium --ozone-platform=wayland --enable-wayland-ime --kiosk --no-first-run --disable-infobars --disable-session-crashed-bubble --enable-touch-events \"$URL\"
fi

echo \"[kiosk] Weston failed -> falling back to X11\" >>\$WAYLOG
unset QT_QPA_PLATFORM
echo \"[kiosk] starting X :1\" >\$XLOG
startx ~/.xsession -- :1 >>\$XLOG 2>&1
SK
chmod +x ~/start_kiosk.sh"

# ───────────────────────────── .bash_profile ───────────────────────────────
echo "• Writing .bash_profile to call kiosk launcher"
as_gui "cat >~/.bash_profile <<'BP'
[[ -z \$WAYLAND_DISPLAY && \$(tty) = /dev/tty1 ]] && ~/start_kiosk.sh
BP
chmod 644 ~/.bash_profile"

# ───────────────────────────── restart getty ───────────────────────────────
systemctl daemon-reload
systemctl restart getty@tty1

echo "===== INSTALL FINISHED at $(date) ====="
echo
echo ">> Reboot or switch to TTY1. Weston should appear briefly."
echo "   • If Wayland path succeeds, the Weston keyboard pops on focus."
echo "   • If not, fallback X11 opens and Onboard pops on focus."
echo
echo "   Wayland log : /home/gui/kiosk-wayland.log"
echo "   X11 log     : /home/gui/kiosk-x11.log"
SCRIPT

chmod +x install_kiosk_full.sh
echo "Installer saved to $(pwd)/install_kiosk_full.sh  — now run:"
echo "   sudo ./install_kiosk_full.sh"
