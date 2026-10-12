#!/bin/sh
set -eu
printf '%s\n' 'bb08d0e6ce7e8037900bb385333b74abfbce84c3c6af34fed3899388bd45fde7  /tmp/gta4l-upload/camera-gta4l-1.0-r0.apk' | sha256sum -c -
printf '%s\n' '2000f25a9d6474863fceeb79faf0b3323781e0d42b90ba0b9a36f5ae064c2a19  /tmp/gta4l-upload/camera-gta4l-openrc-1.0-r0.apk' | sha256sum -c -
apk add --allow-untrusted /tmp/gta4l-upload/camera-gta4l-1.0-r0.apk /tmp/gta4l-upload/camera-gta4l-openrc-1.0-r0.apk
printf '%s\n' '3dfa3c004119eea2e70114689ea39025a60c1349f7564977626c5b0974f378a8  /usr/lib/gta4l-camera/runtime/vendor/lib64/hw/camera.qcom.so' | sha256sum -c -
rc-service gta4l-camera start
rc-update add gta4l-camera default
printf 'CAMERA_PACKAGE_R0_INSTALLED\n'
