#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
BUILDROOT="$ROOT/work/chroot_buildroot_aarch64"
mounted_native=false
if ! mountpoint -q "$BUILDROOT/native"; then
    mkdir -p "$BUILDROOT/native"
    mount --bind "$ROOT/work/chroot_native" "$BUILDROOT/native"
    mounted_native=true
fi
cleanup() { if "$mounted_native"; then umount "$BUILDROOT/native"; fi; }
trap cleanup EXIT
mkdir -p "$BUILDROOT/tmp/gta4l-gpu-test"
cp "$WORKSPACE/tools/gpu-compute-test.c" "$WORKSPACE/tools/gpu-compute.comp" "$BUILDROOT/tmp/gta4l-gpu-test/"
chroot "$BUILDROOT" /usr/bin/glslangValidator -V /tmp/gta4l-gpu-test/gpu-compute.comp -o /tmp/gta4l-gpu-test/gpu-compute.spv
chroot "$BUILDROOT" /usr/bin/env LD_LIBRARY_PATH=/native/usr/lib:/native/lib \
    /native/usr/bin/aarch64-alpine-linux-musl-gcc \
    -B/native/usr/libexec/gcc/aarch64-alpine-linux-musl/15.2.0/ \
    -B/native/usr/lib/gcc/aarch64-alpine-linux-musl/15.2.0/ \
    -B/native/usr/aarch64-alpine-linux-musl/bin/ -B/usr/lib/ \
    --sysroot=/ -O2 -Wall -Wextra -Werror -I/usr/include \
    /tmp/gta4l-gpu-test/gpu-compute-test.c -L/usr/lib -lvulkan \
    -o /tmp/gta4l-gpu-test/gpu-compute-test
mkdir -p "$WORKSPACE/artifacts/gpu"
cp "$BUILDROOT/tmp/gta4l-gpu-test/gpu-compute-test" "$BUILDROOT/tmp/gta4l-gpu-test/gpu-compute.spv" "$WORKSPACE/artifacts/gpu/"
file "$WORKSPACE/artifacts/gpu/gpu-compute-test"
sha256sum "$WORKSPACE/artifacts/gpu/"*
