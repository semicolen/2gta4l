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
mkdir -p "$BUILDROOT/tmp/gta4l-wlfw"
cp "$WORKSPACE/tools/wlfw-capability-query.c" "$BUILDROOT/tmp/gta4l-wlfw/"
chroot "$BUILDROOT" /usr/bin/env LD_LIBRARY_PATH=/native/usr/lib:/native/lib \
    /native/usr/bin/aarch64-alpine-linux-musl-gcc \
    -B/native/usr/libexec/gcc/aarch64-alpine-linux-musl/15.2.0/ \
    -B/native/usr/lib/gcc/aarch64-alpine-linux-musl/15.2.0/ \
    -B/native/usr/aarch64-alpine-linux-musl/bin/ -B/usr/lib/ \
    --sysroot=/ -O2 -Wall -Wextra -Werror -I/usr/include \
    /tmp/gta4l-wlfw/wlfw-capability-query.c -o /tmp/gta4l-wlfw/wlfw-capability-query
mkdir -p "$WORKSPACE/artifacts/wlan"
cp "$BUILDROOT/tmp/gta4l-wlfw/wlfw-capability-query" "$WORKSPACE/artifacts/wlan/"
cp "$WORKSPACE/port/wlfw-gta4l/wlfw-initialize.c" "$BUILDROOT/tmp/gta4l-wlfw/"
chroot "$BUILDROOT" /usr/bin/env LD_LIBRARY_PATH=/native/usr/lib:/native/lib \
    /native/usr/bin/aarch64-alpine-linux-musl-gcc \
    -B/native/usr/libexec/gcc/aarch64-alpine-linux-musl/15.2.0/ \
    -B/native/usr/lib/gcc/aarch64-alpine-linux-musl/15.2.0/ \
    -B/native/usr/aarch64-alpine-linux-musl/bin/ -B/usr/lib/ \
    --sysroot=/ -O2 -Wall -Wextra -Werror -I/usr/include \
    /tmp/gta4l-wlfw/wlfw-initialize.c -o /tmp/gta4l-wlfw/wlfw-initialize
cp "$BUILDROOT/tmp/gta4l-wlfw/wlfw-initialize" "$WORKSPACE/artifacts/wlan/"
file "$WORKSPACE/artifacts/wlan/wlfw-capability-query"
sha256sum "$WORKSPACE/artifacts/wlan/"*
