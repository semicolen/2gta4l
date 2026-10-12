#!/bin/sh
set -eu
cat /proc/sys/kernel/random/boot_id
rc-service gta4l-sensors status
rc-service iio-sensor-proxy status
cat /home/tablet/.cache/gta4l-rotation/status.json 2>/dev/null || true
tail -n 12 /home/tablet/.cache/gta4l-rotation/rotation.log 2>/dev/null || true
export DISPLAY=:0 XAUTHORITY=/home/tablet/.Xauthority
xrandr --current | head -n 4
xinput list-props 8 | head -n 9
tail -n 8 /var/log/gta4l/sensors-private/rpc.log
echo ROTATION_STATE_END
