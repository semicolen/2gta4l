#!/bin/sh
set -u
rc-service polkit status
ps -o pid,ppid,user,args | grep -E 'polkitd|polkit-kde|modemmanager|NetworkManager' | grep -v grep
cat /etc/conf.d/polkit
cat /etc/init.d/polkit
cat /usr/share/dbus-1/system-services/org.freedesktop.PolicyKit1.service
tail -n 70 /var/log/gta4l/polkit.log
tail -n 30 /home/tablet/.local/state/gta4l/plasma-polkit-agent.log
ldd /usr/lib/polkit-1/polkitd
dmesg | grep -Ei 'polkit|segfault' | tail -n 15
