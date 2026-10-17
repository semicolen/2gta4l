#!/bin/sh
set -u
rc-service iio-sensor-proxy status
cat /etc/conf.d/iio-sensor-proxy
echo '=== Recent SensorProxy debug log ==='
tail -n 110 /var/log/gta4l/sensor-proxy-private/debug.log
echo SENSOR_PROXY_DEBUG_SNAPSHOT_COMPLETE
