#!/bin/sh
set -eu
test -c /dev/adsprpc-smd
test -d /sys/devices/virtual/fastrpc/adsprpc-smd
mkdir -p /var/lib/gta4l-ui-qc
target=/etc/udev/rules.d/82-gta4l-wayland-sensors.rules
if [ -f "$target" ] && [ ! -f /var/lib/gta4l-ui-qc/wayland-sensors-rule-before ]; then
    cp "$target" /var/lib/gta4l-ui-qc/wayland-sensors-rule-before
fi
cat > "$target" <<'EOF'
# Native Wayland rotation uses the sensor axes relative to the native panel.
# The Xorg helper's 180-degree mount correction does not apply in this session.
SUBSYSTEM=="fastrpc", KERNEL=="adsprpc-smd", ENV{ACCEL_MOUNT_MATRIX}="1,0,0;0,1,0;0,0,1"
EOF
chmod 0644 "$target"
udevadm control --reload-rules
udevadm trigger --action=change /sys/devices/virtual/fastrpc/adsprpc-smd
udevadm settle --timeout=5
udevadm info --query=property --name=/dev/adsprpc-smd | grep '^ACCEL_MOUNT_MATRIX='
rc-service iio-sensor-proxy restart
sleep 3
gdbus call --system --dest net.hadess.SensorProxy --object-path /net/hadess/SensorProxy \
    --method org.freedesktop.DBus.Properties.GetAll net.hadess.SensorProxy
printf '\nWAYLAND_SENSOR_DIRECTION_CORRECTION_END\n'
