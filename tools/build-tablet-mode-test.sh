#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/ark/sm-t505-port
WS='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
BUILDROOT="$ROOT/work/chroot_buildroot_aarch64"
sh "$WS/tools/ensure-wsl-arm64-emulation.sh"
mounted_native=false
if ! mountpoint -q "$BUILDROOT/native"; then
    mkdir -p "$BUILDROOT/native"
    mount --bind "$ROOT/work/chroot_native" "$BUILDROOT/native"
    mounted_native=true
fi
cleanup() { if "$mounted_native"; then umount "$BUILDROOT/native"; fi; }
trap cleanup EXIT
mkdir -p "$BUILDROOT/tmp/gta4l-tablet-mode" "$WS/artifacts/tablet-mode"
cp "$WS/tools/gta4l-tablet-mode-test.c" "$BUILDROOT/tmp/gta4l-tablet-mode/"
chroot "$BUILDROOT" /usr/bin/env LD_LIBRARY_PATH=/native/usr/lib:/native/lib \
    /native/usr/bin/aarch64-alpine-linux-musl-gcc \
    -B/native/usr/libexec/gcc/aarch64-alpine-linux-musl/15.2.0/ \
    -B/native/usr/lib/gcc/aarch64-alpine-linux-musl/15.2.0/ \
    -B/native/usr/aarch64-alpine-linux-musl/bin/ -B/usr/lib/ \
    --sysroot=/ -O2 -Wall -Wextra -Werror -I/usr/include \
    /tmp/gta4l-tablet-mode/gta4l-tablet-mode-test.c \
    -o /tmp/gta4l-tablet-mode/gta4l-tablet-mode-test
cp "$BUILDROOT/tmp/gta4l-tablet-mode/gta4l-tablet-mode-test" "$WS/artifacts/tablet-mode/"
sha256sum "$WS/artifacts/tablet-mode/gta4l-tablet-mode-test"
