#!/bin/sh
set -eu
apk info -v | grep -E '^(modemmanager|libmm-glib|gps-gta4l)-'
sha256sum /dev/mmcblk0p69
rc-service modemmanager status
