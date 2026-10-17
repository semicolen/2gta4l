#!/bin/sh
set -eu
test "$(id -u)" = 10000
printf '%s\n' 'cf25d848be34f52a65785b1e6e55e7db853f01bc766bfb5c5f869f49853e5d9c  /tmp/gta4l-upload/gpu-egl-render-test' | sha256sum -c -
chmod 700 /tmp/gta4l-upload/gpu-egl-render-test
timeout 25 gta4l-zink-run /tmp/gta4l-upload/gpu-egl-render-test --require-hardware
echo GNOME_ROOTFS_ADRENO_SHADER_READBACK_PASS
