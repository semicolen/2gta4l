#!/bin/sh
set -eu
date
uname -a
cat /proc/sys/kernel/random/boot_id
apk list --installed device-samsung-gta4l rotation-gta4l sensors-gta4l xfce4-screensaver
rc-service gta4l-sensors status
rc-service iio-sensor-proxy status
rc-service gta4l-adsp status
ps -eo pid,args | grep -E 'hexagonrpc|sensor-proxy|lightdm|gta4l-rotate' | grep -v grep
tail -n 25 /var/log/gta4l/sensors-private/rpc.log
timeout 12 monitor-sensor --accel || test "$?" = 143
echo ROTATION_AFTER_REBOOT_END
