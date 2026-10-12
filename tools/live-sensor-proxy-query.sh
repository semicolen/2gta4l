#!/bin/sh
set -eu
rc-service iio-sensor-proxy status || true
ps -eo pid,args | grep -E 'hexagonrpc|sensor-proxy' | grep -v grep || true
gdbus call --system --dest net.hadess.SensorProxy --object-path /net/hadess/SensorProxy --method org.freedesktop.DBus.Properties.GetAll net.hadess.SensorProxy
echo SENSOR_PROXY_QUERY_END
