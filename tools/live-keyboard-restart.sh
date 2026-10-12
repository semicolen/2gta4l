#!/bin/sh
set -eu
session=$(pgrep -u tablet -x xfce4-session | head -n 1)
test -n "$session"
command -v onboard
for name in DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR; do
    value=$(tr '\000' '\n' < "/proc/$session/environ" | sed -n "s/^$name=//p" | head -n 1)
    if [ -n "$value" ]; then export "$name=$value"; fi
done
for pid in $(pgrep -u tablet -x onboard || true); do
    kill -TERM "$pid"
done
sleep 1
su -p tablet -c 'nohup onboard > /home/tablet/.local/state/gta4l/onboard.log 2>&1 < /dev/null &'
sleep 2
pgrep -a -u tablet -x onboard
su -p tablet -c 'dbus-send --session --print-reply --dest=org.onboard.Onboard /org/onboard/Onboard/Keyboard org.freedesktop.DBus.Introspectable.Introspect'
tail -n 25 /home/tablet/.local/state/gta4l/onboard.log
echo KEYBOARD_RESTART_END
