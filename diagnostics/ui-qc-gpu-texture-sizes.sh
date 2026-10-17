#!/bin/sh
set -eu
test "$(id -u)" = 10000
printf '%s\n' '8219cea81fb97b0b5f3918e794e2e5201ea559f83865da6685dfbbc62a27d661  /tmp/gta4l-upload/gpu-texture-size-test' | sha256sum -c -
chmod 700 /tmp/gta4l-upload/gpu-texture-size-test
timeout 70 gta4l-zink-run /tmp/gta4l-upload/gpu-texture-size-test
echo GPU_TEXTURE_SIZE_REGRESSION_COMPLETE
