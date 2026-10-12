#!/bin/sh
set -eu
boot_hash() { head -c 28938256 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum -c - <<'HASHES'
0ddcd6499afda9d634eb037f8c01c06a2c0ee1e28bb45ed5319cdb0d83ab937c  /tmp/gta4l-upload/device-samsung-gta4l-1-r16.apk
057366bc14a41ac4debb92e94c7ddf5688d8ce0c065452899422b86d013ae644  /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r16.apk
0c6ab9328fee1537b10ed7728a4c948463ca414d5c26a9fd96bf323991224852  /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r16.apk
5771b14f348e6d45ffe036487049a4feb4a9e382a73155874935bf46c0fed8c3  /tmp/gta4l-upload/xfce4-screensaver-4.20.2-r1.apk
HASHES
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/device-samsung-gta4l-1-r16.apk /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r16.apk /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r16.apk /tmp/gta4l-upload/xfce4-screensaver-4.20.2-r1.apk
if [ -f /etc/udev/rules.d/81-gta4l-sensors.rules.apk-new ]; then
    cp /etc/udev/rules.d/81-gta4l-sensors.rules /var/lib/gta4l-sensors/81-gta4l-sensors.before-packaging.rules
    mv /etc/udev/rules.d/81-gta4l-sensors.rules.apk-new /etc/udev/rules.d/81-gta4l-sensors.rules
fi
rc-update -q add gta4l-sensors default
rc-update -q add iio-sensor-proxy default
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
echo DEVICE_R16_LOCKSCREEN_FIX_INSTALLED_BOOT_UNCHANGED
