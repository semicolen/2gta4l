#!/usr/bin/env bash
set -euo pipefail
BASE=/home/pmos/sm-t505-port
WS='/mnt/c/postmarketOS-gta4l'
NATIVE="$BASE/work/chroot_native"
BUILD="$NATIVE/tmp/gta4l-camera-build"
RUNTIME="$BASE/camera-development/runtime-root"
mkdir -p "$BUILD/lib"
cp "$WS/tools/camera-hal-enumerate.c" "$BUILD/"
cp "$WS/tools/camera-buffer.h" "$BUILD/"
cp "$RUNTIME/apex/com.android.runtime/lib64/bionic/libc.so" "$BUILD/lib/"
cp "$RUNTIME/apex/com.android.runtime/lib64/bionic/libdl.so" "$BUILD/lib/"
chroot "$NATIVE" /usr/bin/clang --target=aarch64-linux-android31 -ffreestanding \
    -fPIE -pie -O2 -Wall -Wextra -Werror -fno-stack-protector -nostdlib -fuse-ld=lld \
    -Wl,-e,_start -Wl,--export-dynamic -Wl,--dynamic-linker=/apex/com.android.runtime/bin/linker64 \
    -Wl,-z,noexecstack -Wl,-z,relro -Wl,-z,now -Wl,--build-id=sha1 \
    /tmp/gta4l-camera-build/camera-hal-enumerate.c \
    -L/tmp/gta4l-camera-build/lib -Wl,-rpath,/apex/com.android.runtime/lib64/bionic \
    -lc -ldl -o /tmp/gta4l-camera-build/camera-hal-enumerate
cp "$BUILD/camera-hal-enumerate" "$RUNTIME/system/bin/"
chmod 755 "$RUNTIME/system/bin/camera-hal-enumerate"
mkdir -p "$WS/artifacts/camera-development"
cp "$BUILD/camera-hal-enumerate" "$WS/artifacts/camera-development/"
readelf -h "$BUILD/camera-hal-enumerate"
readelf -d "$BUILD/camera-hal-enumerate"
printf 'CAMERA_ENUMERATOR_BUILT_LOCALLY_IN_WSL\n'
