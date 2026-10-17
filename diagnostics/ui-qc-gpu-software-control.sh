#!/bin/sh
set -eu
test "$(id -u)" = 10000
printf '%s\n' 'cf25d848be34f52a65785b1e6e55e7db853f01bc766bfb5c5f869f49853e5d9c  /tmp/gta4l-upload/gpu-egl-render-test' | sha256sum -c -
chmod 700 /tmp/gta4l-upload/gpu-egl-render-test
echo '=== Baseline shader/readback check ==='
LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe XDG_RUNTIME_DIR=/run/user/10000 timeout 20 /tmp/gta4l-upload/gpu-egl-render-test
echo '=== Available graphics test clients ==='
apk --no-network info -L mesa-utils | head -n 80
echo '=== Current driver link targets ==='
ls -l /usr/lib/dri/zink_dri.so /usr/lib/dri/kgsl_dri.so /usr/lib/dri/libdril_dri.so /usr/lib/libgallium*
echo GPU_SOFTWARE_CONTROL_COMPLETE
