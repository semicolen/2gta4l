#!/bin/sh
set -eu
test "$(id -u)" = 10000
export XDG_RUNTIME_DIR=/run/user/10000
command -v strace
chmod 700 /tmp/gta4l-upload/gpu-egl-render-test
set +e
EGL_LOG_LEVEL=debug LIBGL_DEBUG=verbose VK_LOADER_DEBUG=error,warn timeout 25 strace -f -e trace=openat,access,ioctl -o /tmp/gta4l-upload/gnome-egl-loader.strace gta4l-zink-run /tmp/gta4l-upload/gpu-egl-render-test --require-hardware
status=$?
set -e
echo "PROBE_EXIT=$status"
echo '=== Files and GPU/display ioctls ==='
grep -E 'gallium|dril|zink|vulkan|icd|kgsl|/dev/ion|/dev/dri|EACCES|ENOENT' /tmp/gta4l-upload/gnome-egl-loader.strace | tail -n 100
