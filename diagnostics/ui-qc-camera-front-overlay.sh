#!/bin/sh
set -eu
printf '%s\n' '641ca20074d9ba3706ea8d94023cbec99412da071c95e04aaf2bc0a7f69d5a84  /tmp/gta4l-upload/camera-wayland-front-fix.py' | sha256sum -c -
test -f /usr/bin/gta4l-camera
mkdir -p /var/lib/gta4l-ui-qc
if [ ! -f /var/lib/gta4l-ui-qc/camera-r4-before-front-fix.py ]; then
    cp /usr/bin/gta4l-camera /var/lib/gta4l-ui-qc/camera-r4-before-front-fix.py
fi
install -m 0755 -o root -g root /tmp/gta4l-upload/camera-wayland-front-fix.py /usr/bin/gta4l-camera
sha256sum /usr/bin/gta4l-camera
printf 'FRONT_CAMERA_GUI_OVERLAY_READY\n'
