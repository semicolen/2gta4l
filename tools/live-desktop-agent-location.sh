#!/bin/sh
set -u
apk --no-network info -L xfce-polkit
for file in /etc/xdg/autostart/*polkit*.desktop /usr/share/applications/*polkit*.desktop; do
    if [ -f "$file" ]; then grep -E '^Exec=' "$file"; fi
done
echo DESKTOP_AGENT_LOCATION_END
