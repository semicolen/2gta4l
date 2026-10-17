#!/bin/sh
set -u
echo '=== Versions ==='
apk --no-network info -v iio-sensor-proxy libssc hexagonrpc-gta4l sensors-gta4l qrtr
echo '=== Proxy service configuration ==='
cat /etc/init.d/iio-sensor-proxy
echo '=== Processes ==='
ps -eo pid,user,args | grep -E 'hexagonrpc|sensor-proxy' | grep -v grep
echo '=== DSP registry status ==='
qrtr-lookup 400
echo '=== Log candidates ==='
find /var/log -maxdepth 2 -type f -name '*sensor*' -print
echo '=== Device metadata ==='
udevadm info --query=property --name=/dev/adsprpc-smd | grep -E 'SENSOR|ACCEL|DEVNAME|SUBSYSTEM'
echo SENSOR_PROXY_DETAILS_COMPLETE
