#!/bin/sh
set -eu
cat >/etc/udev/rules.d/81-gta4l-sensors.rules <<'EOF'
# The Bosch axes are rotated 180 degrees relative to portrait on SM-T505.
SUBSYSTEM=="fastrpc", KERNEL=="adsprpc-smd", ENV{IIO_SENSOR_PROXY_TYPE}="ssc-accel", ENV{ACCEL_MOUNT_MATRIX}="-1,0,0;0,-1,0;0,0,1"
EOF
udevadm control --reload
udevadm trigger --subsystem-match=fastrpc --sysname-match=adsprpc-smd
udevadm settle --timeout=5
rc-service iio-sensor-proxy restart
loginctl list-sessions
ps -eo user,pid,args | grep -E 'dbus-daemon|xfce4-terminal' | grep -v grep || true
sleep 2
timeout 10 monitor-sensor --accel || test "$?" = 143
