#!/bin/sh
set -u
LD_LIBRARY_PATH=/tmp/gta4l-trace/lib /tmp/gta4l-trace/bin/strace -o /tmp/gta4l-backlight-writev.log -e trace=write,writev /bin/sh -c 'printf "131\n" > /sys/class/backlight/panel0-backlight/brightness'
echo "Brightness write exit: $?"
cat /tmp/gta4l-backlight-writev.log
echo '=== Desktop processes ==='
ps -eo pid,ppid,comm,args | grep -E 'Xorg|xfce4-session|xfce4-screensaver|xfce4-power-manager|vkcube' | grep -v grep
echo '=== Session bus address ==='
for pid in $(pidof xfce4-session); do
    tr '\000' '\n' < /proc/$pid/environ | grep -E 'DBUS_SESSION_BUS_ADDRESS|XAUTHORITY|DISPLAY|XDG_RUNTIME_DIR'
done
echo BACKLIGHT_SESSION_END
