#!/bin/sh
set -eu
printf '%s\n' 'e7b02751e3b399b03a6522bc5b8c6b01d4759599f61a8a0ea400c3a4bede5874  /tmp/gta4l-upload/79-gta4l-kgsl.rules' | sha256sum -c -
install -m644 /tmp/gta4l-upload/79-gta4l-kgsl.rules /etc/udev/rules.d/79-gta4l-kgsl.rules
udevadm control --reload-rules
udevadm trigger --action=change --sysname-match=kgsl-3d0
udevadm settle --timeout=5
ls -l /dev/kgsl-3d0
echo KGSL_PERMISSIONS_END
