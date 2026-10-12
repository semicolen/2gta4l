#!/bin/sh
set -eu
ROOT=/opt/gta4l-camera-dev/r0
printf '%s\n' '3dfa3c004119eea2e70114689ea39025a60c1349f7564977626c5b0974f378a8  /opt/gta4l-camera-dev/r0/vendor/lib64/hw/camera.qcom.so' | sha256sum -c -
printf '%s\n' '0cbe6243d5569227bd057a0bf94906c9b7314f8976363341f8cb3215e58b6a3f  /tmp/gta4l-upload/camera-hal-enumerate' | sha256sum -c -
cp /tmp/gta4l-upload/camera-hal-enumerate "$ROOT/system/bin/camera-hal-enumerate"
chmod 755 "$ROOT/system/bin/camera-hal-enumerate"
printf 'CAMERA_ENUMERATOR_MATCHED_ABI_INSTALLED\n'
