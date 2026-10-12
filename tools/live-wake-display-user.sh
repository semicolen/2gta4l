#!/bin/sh
set -u
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
export XDG_RUNTIME_DIR=/run/user/10000
pid=$(pidof xfce4-session | awk '{print $1}')
export DBUS_SESSION_BUS_ADDRESS=$(tr '\000' '\n' < /proc/$pid/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
xfce4-screensaver-command --deactivate
xset s reset
xset dpms force on
xset q | tail -n 5
echo WAKE_DISPLAY_USER_END
