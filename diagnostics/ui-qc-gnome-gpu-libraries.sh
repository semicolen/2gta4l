#!/bin/sh
set -u
test "$(id -u)" = 10000 || exit 1
echo '=== Exact wrapper ==='
cat /usr/bin/gta4l-zink-run
echo '=== Private DRI and ICD ==='
ls -la /usr/lib/gta4l-zink/lib/dri /usr/share/gta4l-kgsl
cat /usr/share/gta4l-kgsl/freedreno_icd.aarch64.json
echo '=== Linked libraries ==='
gta4l-zink-run /lib/ld-musl-aarch64.so.1 --list /usr/lib/gta4l-zink/lib/libgallium-26.0.8.so
gta4l-zink-run /lib/ld-musl-aarch64.so.1 --list /usr/lib/gta4l-kgsl/libvulkan_freedreno.so
echo '=== Probe options ==='
command -v strace || true
ls -l /tmp/gta4l-upload/gpu-*
echo '=== Environment relevant to graphics ==='
env | grep -E '^(GALLIUM|LIBGL|MESA|EGL|VK_|LD_|DRI|XDG_RUNTIME)' || true
