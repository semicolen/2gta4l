#!/bin/sh
set -eu
session=$(pgrep -u tablet -x xfce4-session | head -n 1)
test -n "$session"
for name in DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR; do
    value=$(tr '\000' '\n' < "/proc/$session/environ" | sed -n "s/^$name=//p" | head -n 1)
    if [ -n "$value" ]; then export "$name=$value"; fi
done
mkdir -p /home/tablet/.local/state/gta4l
chown tablet:tablet /home/tablet/.local/state/gta4l
agent=$(command -v xfce-polkit || true)
if [ -z "$agent" ] && [ -x /usr/lib/xfce4/xfce-polkit ]; then
    agent=/usr/lib/xfce4/xfce-polkit
fi
test -x "$agent"
export GTA4L_POLKIT_AGENT="$agent"
su -p tablet -c 'nohup "$GTA4L_POLKIT_AGENT" > /home/tablet/.local/state/gta4l/xfce-polkit.log 2>&1 < /dev/null &'
sleep 1
pgrep -a -u tablet xfce-polkit
tail -n 20 /home/tablet/.local/state/gta4l/xfce-polkit.log
echo DESKTOP_POLKIT_RESTART_END
