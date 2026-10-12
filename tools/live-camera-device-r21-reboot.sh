#!/bin/sh
set -eu
rc-service gta4l-camera status
test -e /etc/runlevels/default/gta4l-camera
apk info -v camera-gta4l camera-gta4l-openrc device-samsung-gta4l
printf 'CAMERA_DEVICE_R21_REBOOT_REQUESTED\n'
sync
/sbin/reboot
