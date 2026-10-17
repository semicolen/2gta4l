#!/usr/bin/env bash
set -euo pipefail
WORKSPACE='/mnt/c/Users/darya/Documents/ChatGPT/Postmarket os'
ROOT=/home/ark/sm-t505-port/work/chroot_buildroot_aarch64
NATIVE=/home/ark/sm-t505-port/work/chroot_native
BUILD="$NATIVE/tmp/gta4l-qc-build"
OUT="$WORKSPACE/artifacts/qc-backup-tools"
mkdir -p "$OUT/lib" "$BUILD/include" "$BUILD/lib"
mkdir -p "$BUILD/sysroot/usr/lib"
cp -a "$ROOT/usr/include" "$BUILD/sysroot/usr/"
cp -L "$ROOT/usr/lib/"crt*.o "$ROOT/usr/lib/libc.so" "$ROOT/usr/lib/libc.a" "$BUILD/sysroot/usr/lib/"
cp -L "$ROOT/usr/lib/Scrt1.o" "$ROOT/usr/lib/libssp_nonshared.a" "$BUILD/sysroot/usr/lib/"
cp "$WORKSPACE/tools/qc-backup-stream.c" "$BUILD/"
cp -a "$NATIVE/usr/include/openssl" "$BUILD/include/"
cp -L "$ROOT/usr/lib/libcrypto.so.3" "$BUILD/lib/"
chroot "$NATIVE" /usr/bin/aarch64-alpine-linux-musl-gcc -O2 \
    --sysroot=/tmp/gta4l-qc-build/sysroot -B/tmp/gta4l-qc-build/sysroot/usr/lib/ \
    -Wall -Wextra -Werror -I/tmp/gta4l-qc-build/include \
    -Wl,--dynamic-linker=/tmp/gta4l-qc-tools/ld-musl-aarch64.so.1 \
    -Wl,-rpath,/tmp/gta4l-qc-tools/lib \
    -L/tmp/gta4l-qc-build/lib /tmp/gta4l-qc-build/qc-backup-stream.c \
    -l:libcrypto.so.3 -o /tmp/gta4l-qc-build/qc-backup-stream
cp "$BUILD/qc-backup-stream" "$OUT/"
cp -L "$ROOT/usr/lib/ld-musl-aarch64.so.1" "$OUT/ld-musl-aarch64.so.1"
cp -L "$ROOT/usr/lib/libcrypto.so.3" "$OUT/lib/"
file "$OUT/qc-backup-stream"
