#!/bin/bash
# .xinitrc

# Prevent screen blanking
xset -dpms
xset s off
xset s noblank

# Use dbus-launch to wrap the full Openbox session
exec dbus-launch openbox-session

gui@intouch6:~$ cat .xinitrc
#!/bin/bash

# Prevent screen blanking
xset -dpms
xset s off
xset s noblank

# Use dbus-launch to wrap the full Openbox session
# the next file is .config/openbox/autostart
exec dbus-launch openbox-session
