#!/bin/sh
set -eu
printf 'UI_QC_BASELINE\n'
uname -r
cat /etc/os-release
df -h / /boot
printf '\nMount layout\n'
cat /proc/mounts
printf '\nBlock-device sizes\n'
for device in /dev/mmcblk0 /dev/mmcblk0p69 /dev/mmcblk0p70 /dev/mmcblk0p80; do
    if [ -b "$device" ]; then printf '%s ' "$device"; blockdev --getsize64 "$device"; fi
done
printf '\nRuntime packages\n'
apk info -v device-samsung-gta4l linux-samsung-gta4l camera-gta4l gps-gta4l alsa-ucm-gta4l alsa-ucm-gta4l-pulseaudio modemmanager
printf '\nDefault services\n'
rc-status default
