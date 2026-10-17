#!/bin/sh
set -eu
test "$(id -u)" = 10000
export XDG_RUNTIME_DIR=/run/user/10000
export WAYLAND_DISPLAY=$(python3 -c 'from pathlib import Path; print(next(p.name for p in Path("/run/user/10000").glob("wayland-*") if p.is_socket()))')
echo '=== Isolated Zink surfaceless OpenGL ==='
timeout 20 gta4l-zink-run eglinfo -B -p surfaceless
echo '=== Isolated Zink GLES shader/readback ==='
timeout 25 gta4l-zink-run /tmp/gta4l-upload/gpu-egl-render-test --require-hardware
echo '=== Isolated Zink Wayland OpenGL ==='
timeout 20 gta4l-zink-run eglinfo -B -p wayland
echo GPU_ZINK_PROBES_COMPLETE
