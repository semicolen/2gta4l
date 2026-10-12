#!/bin/sh
set -eu
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
cat /home/tablet/.cache/gta4l-rotation/status.json
xrandr --current --verbose | head -n 32
xdpyinfo | grep -E 'dimensions|resolution' || true
xprop -root _NET_DESKTOP_GEOMETRY _NET_WORKAREA _NET_DESKTOP_VIEWPORT || true
ps -eo user,pid,args | grep -E 'xfdesktop|xfwm4|xfce4-panel' | grep -v grep
tail -n 50 /var/log/Xorg.0.log
command -v xfce4-screenshooter xwd convert || true
cat /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/bits_per_pixel
echo DESKTOP_GEOMETRY_END
