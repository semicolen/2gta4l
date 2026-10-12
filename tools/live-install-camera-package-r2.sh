#!/bin/sh
set -eu
boot_hash() { head -c 28938256 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum -c - <<'HASHES'
2d0e2a8768e4471cd7e5764a498442bc73e79efa4a685e437f6df4af945f3bcf  /tmp/gta4l-upload/camera-gta4l-1.0-r2.apk
888f7f7446faa48f15da32add13d453f5c20190e78af814a3fa008f3635e996c  /tmp/gta4l-upload/camera-gta4l-openrc-1.0-r2.apk
HASHES
rc-service gta4l-camera stop
apk --no-network --no-interactive --no-scripts --allow-untrusted add /tmp/gta4l-upload/camera-gta4l-1.0-r2.apk /tmp/gta4l-upload/camera-gta4l-openrc-1.0-r2.apk
rc-service gta4l-camera start
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
printf 'CAMERA_R2_INSTALLED_BOOT_UNCHANGED\n'
