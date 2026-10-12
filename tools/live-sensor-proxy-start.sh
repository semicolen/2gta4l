#!/bin/sh
set -eu
umask 077
cat >/etc/udev/rules.d/81-gta4l-sensors.rules <<'RULE'
# Downstream FastRPC marker: SSC uses QRTR, never this device node's permissions.
SUBSYSTEM=="fastrpc", KERNEL=="adsprpc-smd", ENV{IIO_SENSOR_PROXY_TYPE}="ssc-accel", ENV{ACCEL_MOUNT_MATRIX}="1,0,0;0,1,0;0,0,1"
RULE
udevadm control --reload-rules
udevadm trigger --action=change --subsystem-match=fastrpc --sysname-match=adsprpc-smd
udevadm settle --timeout=5
udevadm info --query=property --name=/dev/adsprpc-smd
rc-service iio-sensor-proxy start
gdbus call --system --dest net.hadess.SensorProxy --object-path /net/hadess/SensorProxy --method org.freedesktop.DBus.Properties.GetAll net.hadess.SensorProxy
echo SENSOR_PROXY_STARTED_END
