#!/bin/sh
set -eu
rc-service gta4l-sensors status
rc-service iio-sensor-proxy restart
sleep 2
set +e
timeout 12 monitor-sensor --accel
status=$?
set -e
case "$status" in 0|124|143) ;; *) exit "$status" ;; esac
echo SENSOR_PROXY_RESTART_CHECK_COMPLETE
