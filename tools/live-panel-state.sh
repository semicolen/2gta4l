stty -echo
printf '\nGTA4L_PANEL_BEGIN\n'
cat /proc/uptime
for f in /sys/class/drm/card0-DSI-1/status /sys/class/drm/card0-DSI-1/enabled /sys/class/drm/card0-DSI-1/dpms /sys/class/drm/card0-DSI-1/modes /sys/class/backlight/panel0-backlight/*; do
    [ ! -f "$f" ] || { echo "$f"; cat "$f"; }
done
find /sys/devices -name '*esd*' -o -name '*panel*state*' -o -name '*lcd*power*'
ps -eo pid,stat,wchan:20,args | grep -E 'Xorg|lightdm|greeter'
ls -l /usr/lib/libdrm.so* /usr/bin/gdb /usr/bin/modetest
printf '\nGTA4L_PANEL_END\n'
stty echo
