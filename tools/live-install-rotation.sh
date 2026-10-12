#!/bin/sh
set -eu
umask 077
boot_hash() { head -c 28938256 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum -c - <<'HASHES'
cc7c3e5d59de11bfdc703c0c19bdc621a5ad946a2d00ddf093337acce788245b  /tmp/gta4l-upload/firmware-sensors-gta4l-20240703-r0.apk
e3b0b75fd53aaa9edabb90c5df31afa9f6c4c015cc18b25ea2868bf08793b14e  /tmp/gta4l-upload/sensors-gta4l-1.0-r0.apk
941d0b712e355d28827aacbe0faf1f47dbe24a92b279b95df231fb213a18ec48  /tmp/gta4l-upload/sensors-gta4l-openrc-1.0-r0.apk
7df5c044f76d5d58355f371e1a065104a0b79822a6844c2abd371ea4f1b2eb76  /tmp/gta4l-upload/rotation-gta4l-1.0-r0.apk
HASHES
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/firmware-sensors-gta4l-20240703-r0.apk /tmp/gta4l-upload/sensors-gta4l-1.0-r0.apk /tmp/gta4l-upload/sensors-gta4l-openrc-1.0-r0.apk /tmp/gta4l-upload/rotation-gta4l-1.0-r0.apk
udevadm control --reload
udevadm trigger --subsystem-match=fastrpc --sysname-match=adsprpc-smd
udevadm settle --timeout=5
rc-update add gta4l-sensors default
rc-update add iio-sensor-proxy default
rc-service iio-sensor-proxy restart
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
echo ROTATION_PACKAGES_INSTALLED_BOOT_UNCHANGED
