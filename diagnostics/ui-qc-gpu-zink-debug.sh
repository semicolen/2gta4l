#!/bin/sh
set -u
echo '=== Candidate library resolution ==='
gta4l-zink-run /lib/ld-musl-aarch64.so.1 --list /usr/sbin/eglinfo
gta4l-zink-run /lib/ld-musl-aarch64.so.1 --list /usr/lib/gta4l-zink/lib/libgallium-26.2.4.so
echo '=== Candidate EGL initialization diagnostics ==='
EGL_LOG_LEVEL=debug LIBGL_DEBUG=verbose MESA_DEBUG=1 VK_LOADER_DEBUG=error,warn XDG_RUNTIME_DIR=/run/user/10000 timeout 20 gta4l-zink-run eglinfo -B -p surfaceless
echo "EGL probe exit: $?"
echo '=== Candidate shader test diagnostics ==='
EGL_LOG_LEVEL=debug LIBGL_DEBUG=verbose MESA_DEBUG=1 XDG_RUNTIME_DIR=/run/user/10000 timeout 20 gta4l-zink-run /tmp/gta4l-upload/gpu-egl-render-test --require-hardware
echo "Shader probe exit: $?"
echo '=== Trace availability ==='
command -v strace || true
echo GPU_ZINK_DEBUG_COMPLETE
