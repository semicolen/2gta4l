#!/bin/sh
set -u
echo '=== Sensor services ==='
for service in gta4l-sensors iio-sensor-proxy gta4l-adsp gta4l-pd-mapper; do rc-service "$service" status; done
ps -eo pid,uid,args | grep -E 'hexagonrpc|sensor-proxy' | grep -v grep || true
echo '=== Current sensor process startup ==='
tail -n 75 /var/log/gta4l/sensors-private/rpc.log
echo '=== Sensor proxy log paths ==='
cat /etc/conf.d/iio-sensor-proxy
ls -l /var/log/*sensor* /var/log/gta4l/*sensor* 2>/dev/null || true
echo '=== Sensor-related policy and startup messages ==='
grep -Ei 'sensor|ssc|accelerometer|orientation|denied|polkit' /var/log/messages | tail -n 60 || true
udevadm info --query=property --name=/dev/adsprpc-smd | grep -E 'SENSOR|ACCEL|DEVNAME|SUBSYSTEM'
echo SENSOR_HEALTH_COMPLETE
