#!/bin/sh
set -eu
expected=a884496fd71c677165ec2ef3bcb60b1125108919be748814db40c6aaebbbeadb
boot_hash() { head -c 28934160 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = "$expected" ]
printf '%s\n' \
    '0834b751d71e550f4120b76c9f480d1753add405b7678ee560529c1338068278  /tmp/gta4l-upload/device-samsung-gta4l-1-r8.apk' \
    '5f26c0adc43e0bbd60024970650ecda4210f3007b4654cb40cd57b54c5eaaf46  /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r8.apk' \
    'bc93a4fd1b3d951c710962e40727c949f764433a8ce2d709aac84ff6df412f63  /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r8.apk' | sha256sum -c -
apk --no-network --no-interactive --no-scripts add \
    /tmp/gta4l-upload/device-samsung-gta4l-1-r8.apk \
    /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r8.apk \
    /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r8.apk
rc-update -q add gta4l-ipa default
rc-service gta4l-ipa start
udevadm control --reload-rules
udevadm trigger --action=change --sysname-match=kgsl-3d0
[ "$(boot_hash)" = "$expected" ]
echo "Verified normal boot image unchanged: $expected"
echo DEVICE_R8_INSTALL_END
