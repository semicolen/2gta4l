#!/bin/sh
set -eu
session=$(pgrep -u tablet -x xfce4-session | head -n 1)
test -n "$session"
export DBUS_SESSION_BUS_ADDRESS=$(tr '\000' '\n' < "/proc/$session/environ" | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p' | head -n 1)
su -p tablet -c 'dbus-send --session --print-reply --dest=org.onboard.Onboard /org/onboard/Onboard/Keyboard org.onboard.Onboard.Keyboard.Show'
su -p tablet -c 'dbus-send --session --print-reply --dest=org.onboard.Onboard /org/onboard/Onboard/Keyboard org.freedesktop.DBus.Properties.Get string:org.onboard.Onboard.Keyboard string:Visible'
echo KEYBOARD_SHOW_END
