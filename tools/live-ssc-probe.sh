#!/bin/sh
set -eu
cd /tmp/gta4l-upload
printf '%s\n' 'ffffc65e669859f7ab9cede0e3bf22cf648b9f3d91ead0f802166434e01098f3  libssc-0.4.4-r0.apk' | sha256sum -c -
apk --no-interactive --allow-untrusted add ./libssc-0.4.4-r0.apk
timeout 25 ssccli --sensor=accelerometer --timeout=5 --debug
echo SSC_ACCELEROMETER_PROBE_END
