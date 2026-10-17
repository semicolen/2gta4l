#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
SRC="$ROOT/diagnostics/mesa-gpu-source/mesa-26.2.4"
echo '=== Existing Mesa package work ==='
find "$ROOT/work" -maxdepth 9 -type d -name 'mesa-26.2.4' -o -name 'mesa-vulkan-kgsl-gta4l'
echo '=== DRI target layout ==='
cat "$SRC/src/gallium/targets/dri/meson.build"
echo '=== Zink runtime requirements ==='
sed -n '3496,3600p' "$SRC/src/gallium/drivers/zink/zink_screen.c"
echo '=== Compiler toolchain ==='
find "$ROOT/work/chroot_native/usr" -maxdepth 3 -type f -name '*gcc' -o -name '*clang' -o -name '*pkg-config'
echo '=== Buildroot libraries ==='
ls "$ROOT/work/chroot_buildroot_aarch64/usr/lib/libEGL.so" "$ROOT/work/chroot_buildroot_aarch64/usr/lib/libGL.so" "$ROOT/work/chroot_buildroot_aarch64/usr/lib/libvulkan.so" "$ROOT/work/chroot_buildroot_aarch64/usr/include/EGL/egl.h"
