#!/bin/sh
set -eu
# This test is only for the greeter; refuse to terminate a logged-in desktop.
if pidof xfce4-session >/dev/null; then
    echo 'An Xfce session is active; greeter restart refused.'
    exit 1
fi
rc-service lightdm restart
sleep 3
export DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0
xset s off
xset -dpms
xset q | tail -n 7
echo GREETER_RESTART_END
