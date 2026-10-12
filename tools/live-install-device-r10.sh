#!/bin/sh
set -eu
expected=c5ccb4a8993624bdc84f37e7167406319389c7064e6c52100c5ee3d13de0eb11
boot_hash() { head -c 28934160 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = "$expected" ]
sha256sum -c - <<'HASHES'
45b40a7484565b64b7931dc46ae3da0210c7911baf4d43144f036940e2ba7b34  /tmp/gta4l-upload/device-samsung-gta4l-1-r10.apk
537906c543e3e03032016171a682686a98dfb7d7ef312719a670261607e87fb8  /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r10.apk
d677e3942d544261c58ffc7061a15ffbda3b9d18dbe7363ed9c0054700ded6a9  /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r10.apk
HASHES
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/device-samsung-gta4l-1-r10.apk /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r10.apk /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r10.apk
rc-update -q add gta4l-ipa default
rc-update -q add gta4l-adsp default
[ "$(boot_hash)" = "$expected" ]
echo 'Device services installed, ADSP registered for next boot; existing boot image verified unchanged.'
