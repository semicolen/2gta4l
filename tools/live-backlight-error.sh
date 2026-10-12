#!/bin/sh
set -u
LD_LIBRARY_PATH=/tmp/gta4l-trace/lib /tmp/gta4l-trace/bin/strace -o /tmp/gta4l-backlight-write.log -e trace=openat,write /bin/sh -c 'printf "131\n" > /sys/class/backlight/panel0-backlight/brightness'
echo "Brightness write exit: $?"
tail -n 14 /tmp/gta4l-backlight-write.log
dmesg | tail -n 40
echo BACKLIGHT_ERROR_END
