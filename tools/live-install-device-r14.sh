#!/bin/sh
set -eu
boot_hash() { head -c 28934160 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = 'faf5a4a554ffa5b01f2adc92b5fee47719e46b5db4542b3b42be225d451cebef' ]
sha256sum -c - <<'HASHES'
386db0a3bbca7215f74b3297380766ded9a78a807aed511a561306537ca0cbcb  /tmp/gta4l-upload/device-samsung-gta4l-1-r14.apk
623ac9bcd2fd8aa3ebad577bfa1c630d025df10f83cf7e265c5f653aefbe1961  /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r14.apk
de3318604c080a3c8eefd0b5ada276d4d6e4513249aeb420d184647b2af4441c  /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r14.apk
HASHES
apk info -e alsa-ucm-gta4l
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/device-samsung-gta4l-1-r14.apk /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r14.apk /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r14.apk
[ "$(boot_hash)" = 'faf5a4a554ffa5b01f2adc92b5fee47719e46b5db4542b3b42be225d451cebef' ]
echo DEVICE_R14_INSTALLED_BOOT_UNCHANGED
