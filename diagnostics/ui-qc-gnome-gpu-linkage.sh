#!/bin/sh
set -u
export XDG_RUNTIME_DIR=/run/user/10000
echo '=== Test executable linkage ==='
gta4l-zink-run /lib/ld-musl-aarch64.so.1 --list /tmp/gta4l-upload/gpu-egl-render-test
echo '=== DRI linkage ==='
gta4l-zink-run /lib/ld-musl-aarch64.so.1 --list /usr/lib/gta4l-zink/lib/dri/zink_dri.so
echo '=== Explicit private DRI load ==='
gta4l-zink-run python3 - <<'PY'
import ctypes
for path in ('/usr/lib/gta4l-zink/lib/dri/zink_dri.so', '/usr/lib/gta4l-zink/lib/libgallium-26.0.8.so'):
    try:
        lib=ctypes.CDLL(path)
        print('LOAD_OK',path,flush=True)
    except OSError as error:
        print('LOAD_ERROR',path,str(error),flush=True)
PY
echo '=== Compute through identical wrapper ==='
timeout 20 gta4l-zink-run /tmp/gta4l-upload/gpu-compute-test /tmp/gta4l-upload/gpu-compute.spv
echo "WRAPPED_COMPUTE_EXIT=$?"
