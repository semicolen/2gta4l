#!/bin/sh
set -eu
boot_hash() { head -c 28938256 /dev/mmcblk0p69 | sha256sum | cut -d' ' -f1; }
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
sha256sum -c - <<'HASHES'
3342052916ce65b2e2b4521fb3e3ea24cd9347dcb7a1681831560bbf7faa9330  /tmp/gta4l-upload/camera-gta4l-1.0-r1.apk
38a59d53a1e5bc98b874f486a7cd0df2f1ad206b3d0a5713461019bb1984da3e  /tmp/gta4l-upload/camera-gta4l-openrc-1.0-r1.apk
9a651054a300c1994fc633adb4625facecd084d1fa2d0fc6bf61e1e33a9c4693  /tmp/gta4l-upload/device-samsung-gta4l-1-r21.apk
ca1bdca9ced46322559185e4ae87478a1eba9ed37e4b6264701b308972641765  /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r21.apk
a2933c3054210d134c514ac46fb78400f3872b2ce8bdd66780121aa603ae4661  /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r21.apk
HASHES
rc-service gta4l-camera stop
apk --no-network --no-interactive --no-scripts --allow-untrusted add /tmp/gta4l-upload/camera-gta4l-1.0-r1.apk /tmp/gta4l-upload/camera-gta4l-openrc-1.0-r1.apk /tmp/gta4l-upload/device-samsung-gta4l-1-r21.apk /tmp/gta4l-upload/device-samsung-gta4l-openrc-1-r21.apk /tmp/gta4l-upload/device-samsung-gta4l-nonfree-firmware-1-r21.apk
rc-update -q add gta4l-camera default
rc-service gta4l-camera start
[ "$(boot_hash)" = '4d4c3e929d9c87fc807840e13ae8fee946eea99d0aaeb2a5a3605491e8a98663' ]
printf 'CAMERA_DEVICE_R21_INSTALLED_BOOT_UNCHANGED\n'
