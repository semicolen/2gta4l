#!/bin/sh
set -eu
cat /proc/uptime
rc-service gta4l-sensors status || true
rc-service iio-sensor-proxy status || true
ps -eo pid,args | grep -E 'hexagonrpc|sensor-proxy|gta4l-rotate' | grep -v grep || true
tail -n 40 /var/log/gta4l/sensors-private/rpc.log
qrtr-lookup 400 || true
dmesg | grep -Ei 'adsprpc|fastrpc|sensor|ssc|adsp|sensorspd' | tail -n 70
cat /home/tablet/.cache/gta4l-rotation/status.json 2>/dev/null || true
tail -n 8 /home/tablet/.cache/gta4l-rotation/rotation.log 2>/dev/null || true
echo SENSOR_COLDBOOT_DIAGNOSTIC_END
