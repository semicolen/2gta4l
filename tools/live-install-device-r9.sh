#!/bin/sh
set -eu
expected=a884496fd71c677165ec2ef3bcb60b1125108919be748814db40c6aaebbbeadb
boot_hash() { head -c 28934160 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = "$expected" ]
printf '%s\n' \
    'c23e18d3554078c96fec84db6909570dedf478e98d66aa169b1c3e8c016c2824  /tmp/gta4l-upload/device-samsung-gta4l-1-r9.apk' \
    '399487b4d364f3b4adc81153e09e9b1db0f92bff03fbad93a178af2b6ab9a5f9  /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r9.apk' \
    '643ea2e07410654d6c6feb680b613a2ed265849f01285004662293fc0b94876b  /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r9.apk' | sha256sum -c -
apk --no-network --no-interactive --no-scripts add \
    /tmp/gta4l-upload/device-samsung-gta4l-1-r9.apk \
    /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r9.apk \
    /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r9.apk
rc-update -q add gta4l-ipa default
rc-service gta4l-ipa start
udevadm control --reload-rules
udevadm trigger --action=change --sysname-match=kgsl-3d0
[ "$(boot_hash)" = "$expected" ]
echo "Verified normal boot image unchanged: $expected"
echo DEVICE_R9_INSTALL_END
