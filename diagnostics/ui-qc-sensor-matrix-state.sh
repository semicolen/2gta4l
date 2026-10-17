#!/bin/sh
set -eu
printf 'SENSOR_PROXY_SERVICE\n'
rc-service iio-sensor-proxy status
printf '\nACCELEROMETER_UDEV_PROPERTIES\n'
udevadm info --query=property --name=/dev/adsprpc-smd | grep -E 'DEVPATH|DEVNAME|SUBSYSTEM|IIO_SENSOR|ACCEL_MOUNT'
printf '\nPORT_SENSOR_RULE\n'
cat /etc/udev/rules.d/81-gta4l-sensors.rules
printf '\nLOCAL_SENSOR_OVERRIDES\n'
find /etc/udev/rules.d -maxdepth 1 -type f -name '*sensor*' -print
printf '\nSENSOR_PROXY_PROPERTIES\n'
gdbus call --system --dest net.hadess.SensorProxy --object-path /net/hadess/SensorProxy \
    --method org.freedesktop.DBus.Properties.GetAll net.hadess.SensorProxy
printf '\nSENSOR_MATRIX_DIAGNOSTIC_END\n'
