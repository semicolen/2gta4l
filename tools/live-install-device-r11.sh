#!/bin/sh
set -eu
expected=faf5a4a554ffa5b01f2adc92b5fee47719e46b5db4542b3b42be225d451cebef
boot_hash() { head -c 28934160 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = "$expected" ]
sha256sum -c - <<'HASHES'
193cad4ed18baa2a6e84ac9e05273e20c61f96bad5e6b49a3127439b3f281fb7  /tmp/gta4l-upload/device-samsung-gta4l-1-r11.apk
63e05ce4cc4e872a889ee523a7ef62ef458b9e5df55c93d8edfb943cc6d069e9  /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r11.apk
0f23ae7e5090b134fb5a7ff20f3e733daf96ab5f335730ac17567fac89c79826  /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r11.apk
HASHES
apk --no-network --no-interactive --no-scripts add /tmp/gta4l-upload/device-samsung-gta4l-1-r11.apk /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r11.apk /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r11.apk
rc-update -q add gta4l-ipa default
rc-update -q add gta4l-adsp default
rc-update -q add gta4l-dbus-services default
[ "$(boot_hash)" = "$expected" ]
echo 'Device services installed and registered for next boot; existing boot image verified unchanged.'
