#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WS='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
BUILDROOT="$ROOT/work/chroot_buildroot_aarch64"
mounted_native=false
if ! mountpoint -q "$BUILDROOT/native"; then
    mkdir -p "$BUILDROOT/native"
    mount --bind "$ROOT/work/chroot_native" "$BUILDROOT/native"
    mounted_native=true
fi
cleanup() { if "$mounted_native"; then umount "$BUILDROOT/native"; fi; }
trap cleanup EXIT
mkdir -p "$BUILDROOT/tmp/gta4l-gpu-egl-test"
cp "$WS/tools/gpu-egl-render-test.c" "$BUILDROOT/tmp/gta4l-gpu-egl-test/"
chroot "$BUILDROOT" /usr/bin/env LD_LIBRARY_PATH=/native/usr/lib:/native/lib \
    /native/usr/bin/aarch64-alpine-linux-musl-gcc \
    -B/native/usr/libexec/gcc/aarch64-alpine-linux-musl/15.2.0/ \
    -B/native/usr/lib/gcc/aarch64-alpine-linux-musl/15.2.0/ \
    -B/native/usr/aarch64-alpine-linux-musl/bin/ -B/usr/lib/ \
    --sysroot=/ -O2 -Wall -Wextra -Werror -I/usr/include \
    /tmp/gta4l-gpu-egl-test/gpu-egl-render-test.c -L/usr/lib -lEGL -lGLESv2 \
    -o /tmp/gta4l-gpu-egl-test/gpu-egl-render-test
mkdir -p "$WS/artifacts/gpu"
cp "$BUILDROOT/tmp/gta4l-gpu-egl-test/gpu-egl-render-test" "$WS/artifacts/gpu/"
file "$WS/artifacts/gpu/gpu-egl-render-test"
sha256sum "$WS/artifacts/gpu/gpu-egl-render-test"
cp "$WS/tools/gpu-wayland-render-test.c" "$BUILDROOT/tmp/gta4l-gpu-egl-test/"
chroot "$BUILDROOT" /usr/bin/wayland-scanner client-header \
    /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml \
    /tmp/gta4l-gpu-egl-test/xdg-shell-client-protocol.h
chroot "$BUILDROOT" /usr/bin/wayland-scanner private-code \
    /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml \
    /tmp/gta4l-gpu-egl-test/xdg-shell-protocol.c
chroot "$BUILDROOT" /usr/bin/env LD_LIBRARY_PATH=/native/usr/lib:/native/lib \
    /native/usr/bin/aarch64-alpine-linux-musl-gcc \
    -B/native/usr/libexec/gcc/aarch64-alpine-linux-musl/15.2.0/ \
    -B/native/usr/lib/gcc/aarch64-alpine-linux-musl/15.2.0/ \
    -B/native/usr/aarch64-alpine-linux-musl/bin/ -B/usr/lib/ \
    --sysroot=/ -O2 -Wall -Wextra -Werror -I/usr/include \
    /tmp/gta4l-gpu-egl-test/gpu-wayland-render-test.c \
    /tmp/gta4l-gpu-egl-test/xdg-shell-protocol.c \
    -L/usr/lib -lEGL -lGLESv2 -lwayland-client -lwayland-egl -lm \
    -o /tmp/gta4l-gpu-egl-test/gpu-wayland-render-test
cp "$BUILDROOT/tmp/gta4l-gpu-egl-test/gpu-wayland-render-test" "$WS/artifacts/gpu/"
file "$WS/artifacts/gpu/gpu-wayland-render-test"
sha256sum "$WS/artifacts/gpu/gpu-wayland-render-test"
cp "$WS/tools/gpu-gbm-render-test.c" "$BUILDROOT/tmp/gta4l-gpu-egl-test/"
chroot "$BUILDROOT" /usr/bin/env LD_LIBRARY_PATH=/native/usr/lib:/native/lib \
    /native/usr/bin/aarch64-alpine-linux-musl-gcc \
    -B/native/usr/libexec/gcc/aarch64-alpine-linux-musl/15.2.0/ \
    -B/native/usr/lib/gcc/aarch64-alpine-linux-musl/15.2.0/ \
    -B/native/usr/aarch64-alpine-linux-musl/bin/ -B/usr/lib/ \
    --sysroot=/ -O2 -Wall -Wextra -Werror -I/usr/include -I/usr/include/libdrm \
    /tmp/gta4l-gpu-egl-test/gpu-gbm-render-test.c \
    -L/usr/lib -lEGL -lGLESv2 -lgbm -ldrm \
    -o /tmp/gta4l-gpu-egl-test/gpu-gbm-render-test
cp "$BUILDROOT/tmp/gta4l-gpu-egl-test/gpu-gbm-render-test" "$WS/artifacts/gpu/"
file "$WS/artifacts/gpu/gpu-gbm-render-test"
sha256sum "$WS/artifacts/gpu/gpu-gbm-render-test"
